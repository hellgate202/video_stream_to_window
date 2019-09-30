import numpy as np
import cv2
import sys
import math

img = cv2.imread( sys.argv[1] )
new_x = int( sys.argv[2] )
new_y = int( sys.argv[3] )
img = cv2.resize( img, ( new_x, new_y ) )
img = cv2.cvtColor( img, cv2.COLOR_BGR2GRAY )

with open( "./img.hex", "w+" ) as f:
  for y in range( img.shape[0] ):
    for x in range( img.shape[1] ):
      f.write( hex( img[y][x] * 16 )[2 :]+"\n" )
