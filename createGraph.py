#!/usr/bin/python
"""
Create output files for cytoscape from the All-vs-all mysql database
@author Spencer Bliven <sbliven@ucsd.edu>
"""

import sys
import os
import optparse
import getpass

# ignore depricated code in MySQLdb library
import warnings
warnings.filterwarnings("ignore", category=DeprecationWarning)
import MySQLdb

#def outputTable(filename, rows):
#    """Generates a .sif file specifying a graph
#
#    Args:
#      file:         Filename for the output file. It will be overwriten.
#      rows:         An iterator returning a tuple for each row
#    """
#    file = open(filename, 'w')
#    for row in rows:
#        file.write("\t".join(row))

if __name__ == "__main__":
    parser = optparse.OptionParser( usage="usage: python %prog [options] outfile" )
    parser.add_option("-H","--host",help="MySQL host",
            dest="host",default="localhost")
    parser.add_option("-P","--port",help="MySQL port",
            dest="port",type="int",default=6003)
    parser.add_option("-u","--user",help="MySQL user",
            dest="user",default="sbliven")
    parser.add_option("-p",help="Prompt for MySQL password",
            dest="promptPass",action="store_true",default=False)
    parser.add_option("--password",help="MySQL password (will prompt if empty)",
            dest="passwd", type="str",default=None)
    parser.add_option("-D","--database",help="MySQL database",
        dest="db",default="alig")

    (options, args) = parser.parse_args()

    if len(args) != 1:
        parser.print_usage()
        parser.exit("Error: Expected 1 argument, but found %d"%len(args) )

    filename = args[0]

    dbParams = {
            "host" : options.host,
            "port" : options.port,
            "user" : options.user,
            "db" : options.db,
            }

    if options.passwd is not None:
        dbParams["passwd"] = options.passwd
    elif options.promptPass:
        dbParams["passwd"] = getpass.getpass("MySQL password for %s:"%(options.user))
    #else use annonymous passwd


    conn = MySQLdb.connect(**dbParams)

    cursor = conn.cursor()

    query = "SELECT * FROM clustered_pair limit 50;"

    cursor.execute( query )

    file = open(filename,'w')
    for row in cursor.fetchall():
        file.write("\t".join([str(f) for f in row]))
        file.write("\n")

    file.close()
