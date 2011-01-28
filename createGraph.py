#!/usr/bin/python
"""
Create output files for cytoscape from the All-vs-all mysql database
@author Spencer Bliven <sbliven@ucsd.edu>
"""

import sys
import os
import optparse

if __name__ == "__main__":
    parser = optparse.OptionParser( usage="usage: python %prog [options]" )
    parser.add_option("-v","--verbose", help="Long messages",
        dest="verbose",default=False, action="store_true")
    (options, args) = parser.parse_args()

    if len(args) != 0:
        parser.print_usage()
        parser.exit("Error: Expected 0 argument, but found %d"%len(args) )


