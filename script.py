for i in range(64):
    s = ['0'] * 64
    s[63-i] = '1'
    if (i > 0):
        s[63-i+1:63] = '?' * i
    s = ''.join(s)
    print("%s" % s)