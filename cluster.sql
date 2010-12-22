#MYSQL

# Author: Spencer Bliven
#
# Clustering procedures
# Called from alig (production) or aligTest (testing) databases


/* initClusters(maxPval FLOAT)
 * 
 * Initializes clusters from the pair table, creating the cluster and clustered_pair tables.
 * Every node in pair because a cluster of size one.
 * Every edge in pair with probability below maxPval because an edge between clusters.
 */
DROP PROCEDURE IF EXISTS initClusters;
DELIMITER //
CREATE PROCEDURE initClusters(maxPval FLOAT)
BEGIN
    # Create clustered_pair table
    # clustered_pair holds the edges in the clustered graph
    DROP TABLE IF EXISTS clustered_pair;
    CREATE TABLE IF NOT EXISTS clustered_pair (
        id BIGINT(20) UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        name1 VARCHAR(255),
        name2 VARCHAR(255),
        probability FLOAT);
    
    # copy over all completed pairs
    INSERT INTO clustered_pair SELECT id, name1, name2, probability FROM pair WHERE active IS NULL AND complete = 1 AND probability < maxPval;
    
    # Create cluster table
    # Each member of a cluster is labeled with the cluster representative.
    # The size gives the size of the cluster when it was merged.
    # Thus the size of current clusters is given in rows where name=repr
    DROP TABLE IF EXISTS cluster;
    CREATE TABLE IF NOT EXISTS cluster (
        name VARCHAR(255) PRIMARY KEY,
        repr VARCHAR(255) NOT NULL,
        size INT DEFAULT 1 );
    
    # initialize to individual clusters
    INSERT IGNORE INTO cluster (name, repr) SELECT DISTINCT name1, name1 FROM clustered_pair;
    INSERT IGNORE INTO cluster (name, repr) SELECT DISTINCT name2, name2 FROM clustered_pair;
    #INSERT IGNORE INTO cluster SELECT name1, name1 FROM clustered_pair;
    #INSERT IGNORE INTO cluster SELECT name2, name2 FROM clustered_pair;
    
    
    #TODO alter table clustered_pair add index (name1); name2;
END //
DELIMITER ;


/* initClusters(maxPval FLOAT)
 * 
 * Initializes clusters from the pair table, creating the cluster and clustered_pair tables.
 * Every node in pair because a cluster of size one.
 * Every edge in pair with probability below maxPval because an edge between clusters.
 *
 * Only conciders nodes within distance 2 of clusterCenter
 */
DROP PROCEDURE IF EXISTS initClustersAroundName;
DELIMITER //
CREATE PROCEDURE initClustersAroundName(maxPval FLOAT, clusterCenter VARCHAR(255) )
BEGIN
    # Create clustered_pair table
    # clustered_pair holds the edges in the clustered graph
    DROP TABLE IF EXISTS clustered_pair;
    CREATE TABLE IF NOT EXISTS clustered_pair (
        id BIGINT(20) UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        name1 VARCHAR(255),
        name2 VARCHAR(255),
        probability FLOAT);
    
    # Create cluster table
    # Each member of a cluster is labeled with the cluster representative.
    # The size gives the size of the cluster when it was merged.
    # Thus the size of current clusters is given in rows where name=repr
    DROP TABLE IF EXISTS cluster;
    CREATE TABLE IF NOT EXISTS cluster (
        name VARCHAR(255) PRIMARY KEY,
        repr VARCHAR(255) NOT NULL,
        size INT DEFAULT 1 );
        
        
    INSERT INTO cluster (name, repr, size)
    VALUES ( clusterCenter, clusterCenter, 1 );
    
    # Degree 1 nodes
    CALL expandCluster();
    
    /*
    # copy over edges of clusterCenter
    INSERT INTO clustered_pair SELECT id, name1, name2, probability FROM pair 
        WHERE active IS NULL AND complete = 1
        AND probability < maxPval
        AND name1 = clusterCenter;
    INSERT INTO clustered_pair SELECT id, name1, name2, probability FROM pair 
        WHERE active IS NULL AND complete = 1
        AND probability < maxPval
        AND name2 = clusterCenter;
        

    
    # initialize to individual clusters
    INSERT IGNORE INTO cluster (name, repr) SELECT DISTINCT name1, name1 FROM clustered_pair;
    INSERT IGNORE INTO cluster (name, repr) SELECT DISTINCT name2, name2 FROM clustered_pair;
    #INSERT IGNORE INTO cluster SELECT name1, name1 FROM clustered_pair;
    #INSERT IGNORE INTO cluster SELECT name2, name2 FROM clustered_pair;
    
    # copy over edges of existing clusters
    */
    
    #TODO alter table clustered_pair add index (name1); name2;
END //
DELIMITER ;

/* Expands existing clusters by adding in edges from from pair linking existing clusters to new nodes.
 * New nodes are created as new size=1 clusters
 */
DROP PROCEDURE IF EXISTS expandCluster;
DELIMITER //
CREATE PROCEDURE expandCluster()
BEGIN
    
    # insert pairs whose name1 appears in a cluster
    # convert pairs to use representatives for name1 and name2
    INSERT IGNORE INTO clustered_pair (id, name1, name2, probability)
        SELECT pair.id, cluster1.repr, IF(cluster2.repr IS NULL, pair.name2, cluster2.repr), pair.probability
        FROM pair
        JOIN cluster as cluster1
        ON cluster1.name = pair.name1
        LEFT JOIN cluster as cluster2
        ON cluster2.name = pair.name2
        WHERE pair.active IS NULL AND pair.complete = 1;
    # now do the same for the right pairs
    INSERT IGNORE INTO clustered_pair (id, name1, name2, probability)
        SELECT pair.id, IF(cluster1.repr IS NULL, pair.name1, cluster1.repr), cluster2.repr, pair.probability
        FROM pair
        JOIN cluster as cluster2
        ON cluster2.name = pair.name2
        LEFT JOIN cluster as cluster1
        ON cluster1.name = pair.name1
        WHERE pair.active IS NULL AND pair.complete = 1;
    
    # eliminate self-edges
    DELETE FROM clustered_pair where name1 = name2;
    
    # update cluster with the new nodes
    INSERT IGNORE INTO cluster (name, repr, size)
        SELECT name, name, 1
        FROM (
            SELECT name1 AS name FROM clustered_pair UNION SELECT name2 AS name FROM clustered_pair
        ) AS names;
    
    
    
    # eliminate any duplicate pairs which were just introduced.
    CALL dropDuplicatePairs();
END //
DELIMITER ;


/* Looks through clustered_pair for duplicated edges. Removes all but the lowest probability edge.
 * Note that edges are considered directed, so A->B is not a duplicate of B->A.
 */
DROP PROCEDURE IF EXISTS dropDuplicatePairs;
DELIMITER //
CREATE PROCEDURE dropDuplicatePairs()
BEGIN
    DECLARE nDups INT;
    
    # First check if any duplicates exist
    SELECT count(*) FROM 
        (   SELECT name1, name2, count(*)
            FROM clustered_pair
            GROUP BY name1, name2
            HAVING count(*) > 1
        ) AS duplicates INTO nDups;
    IF nDups > 0 THEN
        SET @idx=0;
        SET @cur_name1="";
        SET @cur_name2="";
        
        #Use lots of temp tables, since nested subqueries are buggy?
        DROP TABLE IF EXISTS indexed_edges;
        CREATE TEMPORARY TABLE indexed_edges
            SELECT id, name1, name2, probability,
                IF(@cur_name1 != name1 OR @cur_name2 != name2, @idx:=1, @idx:=@idx+1) AS row_index,
                @cur_name1:=sorted_edges.name1,
                @cur_name2:=sorted_edges.name2
            FROM (
                SELECT id, name1, name2, probability
                FROM clustered_pair
                ORDER BY name1, name2, probability
            ) AS sorted_edges;
            
        #TODO This is poorly optimized. Better version?
        DELETE FROM clustered_pair WHERE id IN (
            SELECT id FROM indexed_edges WHERE row_index > 1 );
    END IF;
    
    /*
    # Output non-directed duplicate edges
    SELECT IF(cp1.probability < cp2.probability, cp1.id, cp2.id) AS id,
        IF(strcmp(cp1.name1, cp1.name2) < 0, cp1.name1, cp1.name2) AS name1, 
        IF(strcmp(cp1.name1, cp1.name2) < 0, cp1.name2, cp1.name1) AS name2, 
        IF(cp1.probability < cp2.probability, cp1.probability, cp2.probability) AS probability
    FROM clustered_pair AS cp1
    JOIN clustered_pair AS cp2
    ON cp1.name1 = cp2.name2 and cp1.name2 = cp2.name1;
    */
END //
DELIMITER ;


/* mergeClusters(pairID INT)
 *
 * pairID refers to the id of a row in clustered_pair.
 * This procedure merges the two clusters bound by that edge.
 *
 * Precondition: initClusters() has been run to initialize tables
 */
DROP PROCEDURE IF EXISTS mergeClusters;
DELIMITER //
CREATE PROCEDURE mergeClusters(pairID INT)
BEGIN
    SELECT name1, name2 FROM clustered_pair WHERE id = pairID INTO @rep, @merge;
    SELECT size FROM cluster WHERE name = @rep INTO @repSize;
    SELECT size FROM cluster WHERE name = @merge INTO @mergeSize;
    DELETE FROM clustered_pair WHERE id = pairID;

    #Select larger cluster as @repr
    IF (@repSize < @mergeSize) THEN
        SET @temp = @merge;
        SET @merge = @rep;
        SET @rep = @temp;
    END IF;
    
    #Transfer all edges from @merge to @rep
    UPDATE clustered_pair SET name1 = @rep WHERE name1 = @merge;
    UPDATE clustered_pair SET name2 = @rep WHERE name2 = @merge;

    #Create temporary table with all the edges to @rep or @merge
    DROP TABLE IF EXISTS rep_pair;
    CREATE TEMPORARY TABLE rep_pair SELECT id, name2 AS name, probability FROM clustered_pair WHERE name1 = @rep;
    INSERT INTO rep_pair SELECT id, name1, probability FROM clustered_pair WHERE name2 = @rep;
    #CREATE OR REPLACE VIEW rep_pair AS SELECT id, name2 AS name, probability FROM clustered_pair WHERE name1 = @rep UNION SELECT id, name1 AS name, probability FROM clustered_pair WHERE name2 = @rep;
    
    #Create temp table with the edges we are going to keep, eg those that have minimal probability
    #TODO BUG: If one node has edges to both @rep and @merge with equal probability
    #DROP TABLE IF EXISTS min_prob;
    #CREATE TEMPORARY TABLE min_prob AS SELECT name, MIN(probability) AS min_prob FROM rep_pair GROUP BY name;
    

        
    # This complecated query deletes duplicate edges arising from the merge
    # Table r lists the edges to the cluster, sorted by name and probability
    # Table r2 adds a row_index, which restarts at 1 for each name
    # We only delete rows with row_index>1, ie duplicate edges
    SET @idx=0;
    SET @cur_name="";
    
    /* Correct Way, with subqueries:
    DELETE FROM clustered_pair WHERE id IN (
        SELECT id
        FROM (
            SELECT r.id, r.name, r.probability,
                IF(@cur_name != r.name, @idx:=1, @idx:=@idx+1) AS row_index,
                @cur_name:=r.name
            FROM (
                SELECT id, name, probability
                FROM rep_pair
                ORDER BY name, probability
            ) AS r
            HAVING row_index > 1
        ) AS r2
    );
    */
    
    #Use lots of temp tables, since nested subqueries are buggy?
    DROP TABLE IF EXISTS r2;
    CREATE TEMPORARY TABLE r2
        SELECT r.id, r.name, r.probability,
            IF(@cur_name != r.name, @idx:=1, @idx:=@idx+1) AS row_index,
            @cur_name:=r.name
        FROM (
            SELECT id, name, probability
            FROM rep_pair
            ORDER BY name, probability
        ) AS r;
    
    #TODO This is poorly optimized. Better version?
    DELETE FROM clustered_pair WHERE id IN (
        SELECT id FROM r2 WHERE row_index > 1 );
    
    #DELETE FROM clustered_pair WHERE id IN ( SELECT id FROM rep_pair JOIN min_prob ON rep_pair.name = min_prob.name AND rep_pair.probability != min_prob.min_prob );

    UPDATE cluster SET size = @repSize + @mergeSize WHERE name = @rep;
    UPDATE cluster SET repr = @rep WHERE repr = @merge;
    
END //
DELIMITER ;

/* cluster(threshold FLOAT)
 *
 * Cluster data by iteratively merging clusters with the lowest probability,
 * until no edges with probability < threshold exist.
 */
DROP PROCEDURE IF EXISTS cluster;
DELIMITER //
CREATE PROCEDURE cluster(threshold FLOAT)
BEGIN
    SELECT id, probability FROM clustered_pair ORDER BY probability LIMIT 1 INTO @id, @edgePVal;
    WHILE @edgePVal <= threshold AND ( SELECT count(*) FROM clustered_pair WHERE id = @id ) > 0 DO
        #SELECT @id, count(*) FROM clustered_pair WHERE id = @id;
        
        # merge the two closest clusters
        CALL mergeClusters(@id);
        
        # report number of clusters and current pval
        SELECT id, probability FROM clustered_pair ORDER BY probability LIMIT 1 INTO @id, @edgePVal;
    END WHILE;
    
END //
DELIMITER ;

/* main function
 *
 * Cluster low-pval terms, reporting the number of clusters and edges at each order of magnitude
 */
DROP PROCEDURE IF EXISTS main;
DELIMITER //
CREATE PROCEDURE main(maxComponents INT, maxPval FLOAT)
BEGIN
    DROP TABLE IF EXISTS report;
    CREATE TABLE report (
        pVal FLOAT,
        numClusters INT,
        numEdges INT
    );


    CALL initClusters(maxPval);
        
    SET @pVal = -1;
    SET @numClusters = maxComponents;
    SET @numEdges = maxComponents;
    WHILE @numClusters + @numEdges > maxComponents AND @pVal <= 1 DO
        CALL cluster(@pVal);
        
        SELECT count(*) FROM cluster WHERE name = repr INTO @numClusters;
        SELECT count(*) FROM clustered_pair INTO @numEdges;
        
        #Output statistics
        INSERT INTO report VALUES ( @pVal, @numClusters, @numEdges );

        # Report unclustered, probability = 0, and then probability <= e^-i for i=1,2,...
        CASE
            WHEN @pVal < 0 THEN SET @pVal=0;
            WHEN @pVal = 0 THEN SET @pVal=1e-18;
            ELSE SET @pVal=@pVal*10;
        END CASE;
    END WHILE;

END //
DELIMITER ;

#Example:
#CALL main(10, .5); #Run clustering
#SELECT * from report; #Read progress