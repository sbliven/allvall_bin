-- MYSQL
--
-- Author: Spencer Bliven
--
-- Initialize the 'sigPair' table with a snapshot of significant edges from pair

CREATE TABLE sigPair (
    id          BIGINT(20) UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    name1       VARCHAR(255),
    name2       VARCHAR(255),
    len1        INT,
    len2        INT,
    score       FLOAT,
    sim1        INT,
    sim2        INT,
    probability FLOAT,
    rmsdOpt     FLOAT,
    filePath    VARCHAR(60),
    pid         INT(3)
) ENGINE=InnoDB;

INSERT INTO sigPair (id, name1, name2, len1, len2, score, sim1, sim2, probability, rmsdOpt, filePath, pid)
SELECT id, name1, name2, len1, len2, score, sim1, sim2, probability, rmsdOpt, filePath, pid
FROM pair
WHERE active IS NULL AND complete = 1
    AND probability < 0.001
    AND len1 > 20 AND len2 > 20
    AND sim1 > 20 AND sim2 > 20
;

-- List name1, name2 alphabetically
UPDATE sigPair SET name1=name2, name2=name1 
WHERE name1 > name2;
