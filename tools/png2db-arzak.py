#!/usr/bin/env python3
import png
import sys
import os
from subprocess import call, Popen, PIPE
from math import *
from operator import itemgetter
from utils import *
from base64 import b64encode
import array

TOOLS = './tools/'
SALVADOR = TOOLS + 'salvador.exe'
workdir = 'tmp/'

VARCHUNK=2
LEFTOFS=0
TOPOFS=0
mode='varblit'
save_as_zdb = False # spiralbox special: pal + pic | salvador

# if cell is empty and all cells in this column above it are empty
#       check cell directly below and if it is not empty consider current one not empty as well
#
# if cell is empty and all cells in this column under it are empty
#       check cell directly above and if it is not empty, consider current one not empty as well
#   
# step 1: shrinkwrap
# step 2: profit



def shrinkwrap(plane, ncolumns):
    rows = list(chunker(plane, ncolumns))
    hull = [[1 for x in range(len(rows[0]))] for y in range(len(rows))]

    for x in range(len(rows[0])):
        y1 = 0
        y2 = len(rows) - 1
        top_end = bottom_end = False
        while y1 < y2 and not (top_end and bottom_end):
            if rows[y1][x] == 0 and rows[y1+1][x] == 0 and rows[y1+2][x] == 0:
                hull[y1][x] = 0
                y1 += 1
            else:
                top_end = True
            if rows[y2][x] == 0 and rows[y2-1][x] == 0 and rows[y2-2][x] == 0:
                hull[y2][x] = 0
                y2 -= 1
            else:
                bottom_end = True
    #for h in hull:
    #    print(h)
    return hull



# use precalculated offset instead of number of 2-col chunks
def varformat(plane, ncolumns, hull):
    rows = list(chunker(plane, ncolumns))
    #print(hull)

    for y in range(len(rows)):
        #print(line)
        line = rows[y]
        first = 0
        while first < len(line) and hull[y][first] == 0:
            first = first + 1
        last = len(line) - 1
        while last > first and hull[y][last] == 0:
            last = last - 1
        columns = list(chunker(line[first:last+1], VARCHUNK))
        end = len(columns)

        jump = (16 - end) * 5
        dbline = '.db %d, %d ' % (first + LEFTOFS, jump)
        #dbline = '.db %d, %d ' % (first, end)
        for c in columns[:end]:
            for i in range(VARCHUNK - len(c)):
                c.append(0)
            dbline = dbline + ',' + ','.join(['$%02x' % x for x in c])
        print(dbline)
    print('.db 255, 255 ; end of plane data')

def convertpal(pngpal):
    vpal=[]
    #print(pngpal)
    for rgb in pngpal:
        r = floor(rgb[0]/32)
        g = floor(rgb[1]/32)
        b = floor(rgb[2]/64)
        #print(r, g, b)
        vpal.append((b << 6) | (g << 3) | r)

    return vpal

def readPNG(filename):
    reader = None
    pix = None
    w, h = -1, -1
    try:
        if reader == None:        
            reader=png.Reader(filename)
        img = reader.read()
        #print('img=', repr(img))
        pix = list(img[2])
    except:
        print(f'; Could not open image {filename}, file exists?')
        return None
    w, h = len(pix[0]), len(pix)
    print ('; Opened image %s %dx%d' % (filename, w, h))            
    pngpal = None
    pal = None
    try:
        pngpal = img[3]['palette']
        pal = convertpal(pngpal)
    except:
        pass
    return pix, pal, pngpal

foreground=''
glitchframe=''
lineskip=2
nplanes=1


lut = [0] * 256 # for grayscale input
lut[255] = 1    # if grayscale b&w
lut[1] = 1      # for indexed 1bpp
lut[2] = 2
lut[3] = 3

labels=['', '', '', '']

try:
    i = 1
    while i < len(sys.argv):
        if sys.argv[i][0] == '-':
            if sys.argv[i] == '-lineskip':
                lineskip = int(sys.argv[i+1])
                i += 1
            if sys.argv[i] == '-nplanes':
                nplanes = int(sys.argv[i+1])
                i += 1
            if sys.argv[i] == '-lut':
                userlut = [int(x) for x in sys.argv[i+1].split(',')]
                for n,c in enumerate(userlut):
                    lut[n] = c
                print(f'; lut={lut}')
                i += 1
            if sys.argv[i] == '-leftofs':
                LEFTOFS = int(sys.argv[i+1])
                i += 1
            if sys.argv[i] == '-topofs':
                TOPOFS = int(sys.argv[i+1])
                i += 1
            if sys.argv[i] == '-labels':
                userlabels = [s for s in sys.argv[i+1].split(',')]
                for n, l in enumerate(userlabels):
                    labels[n] = l
                i += 1
            if sys.argv[i] == '-mode':
                mode = sys.argv[i+1]
                i += 1
            if sys.argv[i] == '-zdb':
                save_as_zdb = True
        elif foreground == '':
            foreground = sys.argv[i]
        elif glitchframe == '':
            glitchframe = sys.argv[i]
        i += 1
except:
    sys.stderr.write('failed to parse args\n')
    exit(1)

(origname, ext) = os.path.splitext(foreground)
pic, pal, pngpal = readPNG(foreground)

ncolumns = len(pic[0])//8

# indexed color, lines of bytes
#print('xbytes=', xbytes, ' nlines=', nlines)

def starprint(pic):
    print('; ', ''.join([chr(ord('0') + x) if x > 0 else ' ' for x in pic]))


def pixels_to_bitplanes(pic, lineskip):
    planes = [[], [], [], []]
    nlines = len(pic)
    for y in range(0, nlines, lineskip):
        luc = [lut[c] for c in pic[y]]
        starprint(luc)
        for col in chunker(luc, 8):
            c1 = sum([(c & 1) << (7-i) for i, c in enumerate(col)])
            planes[0].append(c1)
            c2 = sum([((c & 2) >> 1) << (7-i) for i, c in enumerate(col)])
            planes[1].append(c2)
            c3 = sum([((c & 4) >> 2) << (7-i) for i, c in enumerate(col)])
            planes[2].append(c3)
            c4 = sum([((c & 8) >> 3) << (7-i) for i, c in enumerate(col)])
            planes[3].append(c4)
    return planes

# second gen:
# 0,0,sz=4
# c = 2,0 2,2 0,2
def progsq(oy, ox, hs):
    return [(oy + hs, ox), (oy + hs, ox + hs), (oy, ox + hs)]

# make the progressive squares sequence
def progseq(result, oy = 0, ox = 0, sz = 8):
    if sz == 1:
        return

    hs = sz//2

    level = []
    if sz == 8:
        level += [(oy,ox)]

    level += progsq(oy, ox, hs)

    sub = []
    for tile in level:
        sub += progsq(tile[0], tile[1], hs//2)

    result.extend(level)
    result.extend(sub)

    sub2 = []
    for angle in chunker(sub, 3):
        for tile in [(angle[0][0]-2, angle[0][1])] + angle:
            sub2 += progsq(tile[0], tile[1], hs//4)

    result.extend(sub2)

def print_prog_square(pseq):
    m = [[0 for x in range(8)] for y in range(8)]
    for i,o in enumerate(pseq):
        m[o[0]][o[1]] = i

    # print the magic square
    for l in m:
        print(''.join([f'{x:4}' for x in l]))


# simple progressive tile refinement
def sequence_pic(pic):
    nr = len(pic)
    nc = len(pic[0])

    pseq = []
    progseq(pseq)

    # print(f'sequence_pic nr={nr} nc={nc} len pseq={len(pseq)}')

    print_prog_square(pseq)

    x0 = LEFTOFS//8
    y0 = 255-TOPOFS
    result = [x0, y0, nc // 8, nr // 8]
    # 0
    for tl in range(0, nr, 8):
        for tc in range(0, nc, 8):
            result.append(pic[tl][tc])
    #print("first: ", len(result))

    # 1-3   32*32*3
    for tl in range(0, nr, 8):
        for tc in range(0, nc, 8):
            for i in range(1, 3+1):
                y, x = pseq[i]
                y += tl
                x += tc
                result.append(pic[y][x])

    #print("second: ", len(result))

    # 4..16
    for tl in range(0, nr, 8):
        for tc in range(0, nc, 8):
            for i in range(4, 4 + 4*3):
                y, x = pseq[i]
                y += tl
                x += tc
                result.append(pic[y][x])

    #print("third: ", len(result))
    #print("sequence tail: ", pseq[4+4*3:])

    for tl in range(0, nr, 8):
        for tc in range(0, nc, 8):
            for i in range(4 + 4*3, 64):
                y, x = pseq[i]
                y += tl
                x += tc
                result.append(pic[y][x])

    return result             

def verify_sequenced_pic(piq, palette):
    pseq = []
    progseq(pseq)

    nc = piq[2] * 8
    nr = piq[3] * 8
    pic = piq[4:]

    m = [[0 for x in range(nc)] for y in range(nr)] 
    
    i = 0
    for tl in range(0, nr, 8):
        for tc in range(0, nc, 8):
            m[tl][tc] = pic[i]
            i += 1

    for tl in range(0, nr, 8):
        for tc in range(0, nc, 8):
            for n in range(1, 3+1):
                y, x = pseq[n]
                m[tl + y][tc + x] = pic[i]
                i += 1

    for tl in range(0, nr, 8):
        for tc in range(0, nc, 8):
            for n in range(4, 4 + 4*3):
                y, x = pseq[n]
                m[tl + y][tc + x] = pic[i]
                i += 1

    for tl in range(0, nr, 8):
        for tc in range(0, nc, 8):
            for n in range(4 + 4*3, 64):
                y, x = pseq[n]
                m[tl + y][tc + x] = pic[i]
                i += 1

    w = png.Writer(nc, nr, palette=palette, bitdepth=4)
    f = open('verify.png', 'wb')
    w.write(f, m)
    f.close()

#def set_tile(pimak, y, x, sz, value):
#    for row in range(y, y + sz):
#        pimak[row][x:x+sz] = value

def xor_tile(pimak, y, x, sz, value):
    for row in range(y, y + sz):
        for col in range(x, x + sz):
            pimak[row][col] ^= value

# save diff relative to current state instead of absolute value
def sequence_pic_xor(pic, palette):
    nr = len(pic)
    nc = len(pic[0])

    pseq = []
    progseq(pseq)

    # print(f'sequence_pic nr={nr} nc={nc} len pseq={len(pseq)}')

    # image accumulator, simulates progressive rendering on target platform 
    pimak = [[0 for x in range(nc)] for y in range(nr)] 

    x0 = LEFTOFS//8
    y0 = 255-TOPOFS
    result = [x0, y0, nc // 8, nr // 8]

    # 0
    for tl in range(0, nr, 8):
        for tc in range(0, nc, 8):
            result.append(pic[tl][tc])
            xor_tile(pimak, tl, tc, 8, pic[tl][tc])

    #print("first: ", len(result))

    # 1-3   32*32*3
    for tl in range(0, nr, 8):
        for tc in range(0, nc, 8):
            for i in range(1, 3+1):
                y, x = pseq[i]
                y += tl
                x += tc
                xorval = pic[y][x] ^ pimak[y][x]
                result.append(xorval)
                xor_tile(pimak, y, x, 4, xorval)

    #print("second: ", len(result))

    # 4..16
    for tl in range(0, nr, 8):
        for tc in range(0, nc, 8):
            for i in range(4, 4 + 4*3):
                y, x = pseq[i]
                y += tl
                x += tc
                xorval = pic[y][x] ^ pimak[y][x]
                result.append(xorval)
                xor_tile(pimak, y, x, 2, xorval)

    #print("third: ", len(result))
    #print("sequence tail: ", pseq[4+4*3:])

    for tl in range(0, nr, 8):
        for tc in range(0, nc, 8):
            for i in range(4 + 4*3, 64):
                y, x = pseq[i]
                y += tl
                x += tc
                xorval = pic[y][x] ^ pimak[y][x]
                result.append(xorval)
                xor_tile(pimak, y, x, 1, xorval)

    w = png.Writer(nc, nr, palette=palette, bitdepth=4)
    f = open('verify-xor.png', 'wb')
    w.write(f, pimak);
    f.close()

    return result             


if mode == 'varblit':
    # every line:   [offset of first column]
    #               [offset into blit code]
    #               data
    #               $ff, $ff terminates
    planes = pixels_to_bitplanes(pic, lineskip=lineskip)

    pic2 = None
    if glitchframe != '':
        pic2 = readPNG(glitchframe)

    for i in range(nplanes):
        hull = None
        if pic2 != None:
            # if a second frame is specified, create a common hull for 2 frames
            #glitchframe=sys.argv[2]
            pic2 = readPNG(glitchframe)
            print(f'; Using {glitchframe} to calculate common hull')

            glitchplanes = pixels_to_bitplanes(pic2, lineskip=lineskip)

            orplane = [x or y for x, y in zip(planes[i], glitchplanes[i])]
            # for line in chunker(orplane, ncolumns):
            #     starprint(line)

            hull = shrinkwrap(orplane, ncolumns)

        if hull == None:
            # use single hull
            hull = shrinkwrap(planes[i], ncolumns)

        if labels[i] != '':
            print(f'{labels[i]}:')
        varformat(planes[i], ncolumns, hull)
            
elif mode == 'tex2':
    # pre-shifted unwrapped texture in 2-pixel chunks
    # pixel 0:   11000000
    # pixel 1:   00110000
    # pixel 2:   00001100
    # pixel 3:   00000011

    if labels[0] != '':
        print(f'{labels[0]}:')
    #masks = [0xc0, 0x30, 0x0c, 0x03]
    masks = [0xff, 0xff, 0xff, 0xff]
    for line in pic:
        tex = [masks[i % len(masks)] * pixel for i, pixel in enumerate(line)]
        print('\t.db ', ','.join(['$%02x'%x for x in tex]))
        print('\t.db ', ','.join(['$%02x'%x for x in tex]))

elif mode == 'bits8':
    # simple 1bpp bitplane
    data = pixels_to_bitplanes(pic, lineskip=lineskip)

    if labels[0] != '':
        print(f'{labels[0]}:')
    for line in chunker(data[0], 32):
        print('\t.db ', ','.join(['$%02x'%x for x in line]))

    if labels[1] != '':
        print(f'{labels[1]}:')
    for line in chunker(data[1], 32):
        print('\t.db ', ','.join(['$%02x'%x for x in line]))

elif mode == 'ivagor4bpp':
    data = pixels_to_bitplanes(pic, lineskip=lineskip)
    planes = [[0]*32*256, [0]*32*256, [0]*32*256, [0]*32*256]
    width=256//8
    result = []
    for x in range(width):
        for y in range(256):
            for i in range(4):
                planes[i][x * 256 + (255-y)] = data[i][x + y * 32]

    planes.reverse()
    for i in range(4):
        result.extend(planes[i])

    f = open(origname + '.bin', 'wb')
    f.write(bytes(result[256:]))
    f.close()

    pal.reverse()
    if pal != None:
        f = open(origname + '.pal', 'wb')
        f.write(bytes(pal))
        f.close()
    #print('len(result)=', len(result))

elif mode == 'spiralbox' or mode == 'spiralbox-xor':
    if mode == 'spiralbox':
        prog_pic = sequence_pic(pic)
        verify_sequenced_pic(prog_pic, pngpal)
    else:
        prog_pic = sequence_pic_xor(pic, pngpal)

    # group pairs of pixels
    prog_pixels = [(x<<4) | y for x, y in chunker(prog_pic[4:], 2)]
    prog = prog_pic[0:4] + prog_pixels

    if pal != None:
        pal.reverse()

    f = open(origname + '.pic', 'wb')
    f.write(bytes(prog))
    f.close()

    if pal != None:
        f = open(origname + '.pal', 'wb')
        f.write(bytes(pal))
        f.close()

    # merge pal + pic, zx0 using salvador and save as .inc 
    if save_as_zdb:
        workfile = workdir + origname + '.pic'
        workfilez = workfile + '.z'
        
        f = open(workdir + origname + '.pic', 'wb')
        f.write(bytes(pal))
        f.write(bytes(prog))
        f.close()

        with Popen([SALVADOR, "-v", "-classic", "-w 256", workfile, workfilez], stdout=PIPE) as proc:
            print(proc.stdout.read())

        with open(workfilez, 'rb') as fz:
            dataz = fz.read()

        with open(origname + '.inc', 'w') as f:
            for line in chunker(dataz, 32):
                f.write(f'\t.db {",".join(["$%02x" % x for x in line])}\n')
