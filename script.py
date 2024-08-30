for i in range(64):
    s = ['0'] * 64
    s[i] = 1
    if (i > 0):
        s[i-1:0] = '?' * (i-1)
    s = ''.join(s)
    print("%64s" % s)