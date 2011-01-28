#!/usr/bin/python
"""
@author Spencer Bliven <sbliven@ucsd.edu>
"""

from __future__ import print_function
import sys
import os
import optparse
import matplotlib
from matplotlib.pyplot import *
import math

# ignore depricated code in MySQLdb library
import warnings
warnings.filterwarnings("ignore", category=DeprecationWarning)
import MySQLdb


inf = float("inf")

def getPValCountForInterval(conn, a, b ):
    """Queries the database for the number of rows with probabilities in [a,b).
    If a==b, count rows with prob = a.
    If a==None or a==-inf, count rows with prob < b.
    If b==None or b==+inf, count rows with prob >= a.
    """
    if a is None and b is None:
        return None
    elif a == -inf and b == inf:
        condition = "1=1"
    elif a is None or a == -inf:
        condition = "probability < %e" % b
    elif b is None or b == inf:
        condition = "%e <= probability" % a
    elif a == b:
        condition = "probability = %e" % a
    else:
        condition = "%e <= probability and probability < %e" % (a,b)

    query = "select count(probability) from pair where %s ;" % condition

    #print(query)

    cursor = conn.cursor()
    cursor.execute( query )


    row = cursor.fetchone()
    count = int(row[0])
    cursor.close()
    return count

def getCumulativePVal(conn,a):
    """Queries the database for the number of rows with probability <= a.
    If a==inf, count all rows
    """
    query = "select count(*) from pair where active is null and complete = 1 "

    if a is None:
        return None
    elif a == -inf:
        return 0
    elif a == inf:
        query += ";"
    else:
        query += "and probability <= %e ;" % a


    print(query,end='')

    cursor = conn.cursor()
    cursor.execute( query )


    row = cursor.fetchone()
    count = int(row[0])
    cursor.close()

    print(" => %d" % count)
    return count

def plotPvals(breaks, pValCum, toFile=False):

    # plot
    figure()
    xlabel('P-val')
    ylabel('Cumulative')
    title('Cumulative Distribution of p-values in All-vs-all database')
    plot(breaks, [1.*f/total for f in pValCum], 'ro')
    plot(breaks, breaks, 'b-')
    if toFile:
        savefig("pvaldist.eps")
    else:
        show()
    # log-x
    figure()
    xlabel('log P-val')
    ylabel('Cumulative')
    title('Cumulative Distribution of p-values in All-vs-all database')
    plot([math.log10(br) if br > 0 else -20 for br in breaks], [1.*f/total for f in pValCum], 'ro')
    plot([math.log10(br) if br > 0 else -20 for br in breaks], [br if br>0 else 1e-20 for br in breaks], 'b-')
    if toFile:
        savefig("pvaldist_logx.eps")
    else:
        show()
    # log-log
    figure()
    xlabel('log P-val')
    ylabel('log Cumulative')
    title('Cumulative Distribution of p-values in All-vs-all database')
    plot([math.log10(br) if br > 0 else -20 for br in breaks], [math.log10(f)-math.log10(total) for f in pValCum], 'ro')
    plot([math.log10(br) if br > 0 else -20 for br in breaks], [math.log10(br) if br>0 else -20 for br in breaks], 'b-')
    if toFile:
        savefig("pvaldist_loglog.eps")
    else:
        show()


if __name__ == "__main__":
    parser = optparse.OptionParser( usage="usage: python %prog [options]" )
    parser.add_option("-v","--verbose", help="Long messages",
        dest="verbose",default=False, action="store_true")
    parser.add_option("-o","--output", help="Output the length of each read to a file",
            default=False,dest="output", action="store_true")
    (options, args) = parser.parse_args()

    if len(args) != 0:
        parser.print_usage()
        parser.exit("Error: Expected 0 argument, but found %d"%len(args) )


    dbParams = {
            "host" : "developer.rcsb.org",
            "port" : 8888,
            "user" : "pdbdata2",
            "passwd" : "lom5ong0",
            "db" : "alig",
            }


    conn = MySQLdb.connect(**dbParams)

    cursor = conn.cursor()

    minVal = -18 #exponent of smallest pval

    pValdist = dict()

    cumulative = True

    if not cumulative:
        # count pvalues for each logorithmic block
        intervals = [(10**e,10**(e+1)) for e in xrange(minVal,0)]
        intervals.append( (0,0) )
        intervals.append( (1,1) )
        for pair in intervals:
            pValdist[pair] = getPValCountForInterval(conn,pair[0],pair[1])


        # check that minVal is indeed minimal
        subMinimals = getPValCountForInterval(conn,-inf,10**minVal)
        if pValdist[(0,0)] != subMinimals:
            print("Warning: Found %d rows in (-inf,%e), but only %d at 0. Adjust minVal." % (subMinimals, 10**minVal, pValdist[(0,0)]), file=sys.stderr )

        #check that we don't have any illegal pvalues
        improbables = getPValCountForInterval(conn,10**0, inf)
        if pValdist[(1,1)] != improbables:
            print("Warning: Found %d rows in (1,inf), but only %d at 1." % (improbables, pValdist[(1,1)]) , file=sys.stderr )


        #add them up. Ignore the end bounds
        total = sum([val for k,val in pValdist.items() if k[0] != -inf and k[1] != inf])

        print("Found %d rows" % total)

        for (a,b) in sorted(pValdist.keys()):
            print( "[%e, %e)\t= %d (%f%%)" % (a,b,pValdist[(a,b)],100.*pValdist[(a,b)]/total ) )

        # plot
        from matplotlib.pyplot import *
        figure()
        x,y = zip(*[(math.log10(a),v*1./total) for (a,b),v in pValdist.items() if a > 0])
        xlabel('log P-val')
        ylabel('Frequency')
        title('Distribution of p-values in All-vs-all database')

        plot(x,y)

        show()
    else: #cumulative

        breaks = [0]
        breaks.extend([10**e for e in xrange(minVal,-1)])
        breaks.append(0.05)
        breaks.extend([e/10. for e in xrange(1,11)])
        breaks.append(inf)
        
        pValCum = [ getCumulativePVal(conn,br) for br in breaks ]

        total = pValCum[-1]
        if total == 0: total = -1 #signal error w/o divideByZero

        print( "Pval\tcumsum\tcumprob")
        print( "\n".join(["%s\t%s\t%s" % (br,pval,1.*pval/total) for br,pval in zip(breaks, pValCum)]) )

        # plot
        plotPvals(breaks, pValCum, options.output)


