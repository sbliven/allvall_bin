#!/usr/bin/python
"""
Create output files for cytoscape from the All-vs-all mysql database

Arguments:
    includeList A file containing a list of nodes to include. Only the first
                field of each column is used.
    file        A file to filter. Filter columns are set with -c (default 2&3).
                Only rows whos values for those columns appear in the includeList file are
                output.

@author Spencer Bliven <sbliven@ucsd.edu>
"""

import sys
import os
import optparse
import csv

if __name__ == "__main__":
    parser = optparse.OptionParser( usage="usage: python %prog [options] includeList file" )
    parser.add_option("-k","--skip",help="Number of lines to ignore from file (header) [1]",
            dest="header",type="int",default=1)
    parser.add_option("-F","--delimiter", help="Field delimiter in the input files [tab]",
            dest="sep",default="\t")
    parser.add_option("-c","--column",help="Index of a column in the file to filter on. Multiple values allowed. [2,3]",
            dest="columns",type="int")

    (options, args) = parser.parse_args()

    if len(args) != 2:
        parser.print_usage()
        parser.exit("Error: Expected 2 argument, but found %d"%len(args) )

    filterFilename = args[0]
    inFilename = args[1]
    out = sys.stdout

    columns = [1,2]
    if options.columns:
        columns = [i-1 for i in options.columns]

    # build list of included tags
    includeTags = {}
    with open(filterFilename,"r") as filterFile:
        for row in csv.reader(filterFile, delimiter = options.sep):
            includeTags[row[0]] = True

    # filter input based on tags
    with open(inFilename,"r") as inFile:
        for i in xrange(options.header):
            out.write(inFile.readline())

        for row in csv.reader(inFile, delimiter = options.sep):
            includeIt = True
            for col in columns:
                if not includeTags.has_key(row[col]):
                    includeIt = False
                    break

            if includeIt:
                out.write( options.sep.join(row) )
                out.write("\n")



