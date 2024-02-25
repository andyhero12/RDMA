#!/usr/bin/python

# Copyright (c) 2011-2016, The Ohio State University. All rights reserved.
#
# This file is part of the RDMA for Apache Hadoop software package
# developed by the team members of The Ohio State University's
# Network-Based Computing Laboratory (NBCL), headed by Professor
# Dhabaleswar K. (DK) Panda.
#
# For detailed copyright and licensing information, please refer to
# the license file LICENSE.txt in the top level directory. 

import os, sys
import os.path

inFile = sys.argv[1]
outFile = sys.argv[2]

alreadyAdded = sys.argv[3]

match = sys.argv[4]

endFile = sys.argv[5]

if os.path.exists(inFile):
	readFile = open( inFile, 'r' )
	writeFile = open( outFile, 'a' )
	for s in readFile.xreadlines():
		res = s.split();
		if res[0] == match:
			if res[1] not in alreadyAdded:
				writeFile.write( "\t<property>\n" );
				writeFile.write( "\t\t<name>"+res[1]+"</name>\n" );
				writeFile.write( "\t\t<value>"+res[2]+"</value>\n" );
				writeFile.write( "\t</property>\n" )
	if endFile == "Y":
		writeFile.write( "</configuration>" )
	readFile.close()
	writeFile.close()
else:
	writeFile = open( outFile, 'a' )
	writeFile.write( "</configuration>" )
	writeFile.close()
