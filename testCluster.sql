#MYSQL

# Author: Spencer Bliven
#
# Generates test data for all vs all clustering
# Always uses the aligTest database, to avoid overwriting real data

CREATE DATABASE IF NOT EXISTS aligTest;
USE aligTest;

# begin stored procedures. Use // to delimit so they can be pasted into mysql

/* makePair()
 *
 * Creates the pair table and populates it with some test data
 * DO NOT CALL ON PRODUCTION SERVER
 */
DROP PROCEDURE IF EXISTS makePair;
DELIMITER //
CREATE PROCEDURE makePair()
BEGIN
    # Create pair with test data
    DROP TABLE IF EXISTS pair;
    CREATE TABLE IF NOT EXISTS pair (
        id BIGINT(20) UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        name1 VARCHAR(255),
        name2 VARCHAR(255),
        probability FLOAT,
        active TINYINT(1),
        complete TINYINT(1) UNSIGNED DEFAULT 1);
    
    INSERT INTO pair (name1, name2, probability) VALUES ( "A", "B", 0 );
    INSERT INTO pair (name1, name2, probability) VALUES ( "A", "C", 1.0E-9 );
    INSERT INTO pair (name1, name2, probability) VALUES ( "A", "D", 0.1 );
    INSERT INTO pair (name1, name2, probability) VALUES ( "B", "C", 1.0E-8 );
    INSERT INTO pair (name1, name2, probability) VALUES ( "B", "L", 1.0E-5 );
    INSERT INTO pair (name1, name2, probability) VALUES ( "C", "D", 1.0E-5 );
    INSERT INTO pair (name1, name2, probability) VALUES ( "C", "E", 1.0E-4 );
    INSERT INTO pair (name1, name2, probability) VALUES ( "D", "E", 1.0E-9 );
    INSERT INTO pair (name1, name2, probability) VALUES ( "D", "I", 1.0E-8 );
    INSERT INTO pair (name1, name2, probability) VALUES ( "E", "F", 1.0E-9 );
    INSERT INTO pair (name1, name2, probability) VALUES ( "F", "I", 3.0E-10 );
    INSERT INTO pair (name1, name2, probability) VALUES ( "F", "J", 2.0E-10 );
    INSERT INTO pair (name1, name2, probability) VALUES ( "F", "K", 1.0E-8 );
    INSERT INTO pair (name1, name2, probability) VALUES ( "I", "J", 1.0E-10 );
    INSERT INTO pair (name1, name2, probability) VALUES ( "I", "K", 2.0E-9 );
    INSERT INTO pair (name1, name2, probability) VALUES ( "J", "K", 2.0E-9 );
    INSERT INTO pair (name1, name2, probability) VALUES ( "L", "J", 1.0E-4 );
    INSERT INTO pair (name1, name2, probability, complete) VALUES ( "G", "A", 0, NULL);
    INSERT INTO pair (name1, name2, probability, active) VALUES ( "H", "A", 0, 1);
END //
DELIMITER ;

CALL makePair(); #Create test data