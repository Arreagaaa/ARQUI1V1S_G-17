import subprocess

proceso = subprocess.Popen(
    ["/home/crjav/ARQUI1/Project/ARQUI1V1S_G-17/Proyecto1/arm64/fase2/build/live_engine"],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True,
    bufsize=1
)

lecturas = [
    "25,55,40,50,400,120,0",
    "28,60,42,48,600,140,0",
    "32,58,41,52,350,110,0",
    "38,63,39,47,700,160,0",
    "40,61,45,53,300,100,0",
]

for l in lecturas:
    temp = l.split(",")[0]
    proceso.stdin.write(l + "\n")
    proceso.stdin.flush()
    print(temp + " ->")
    for _ in range(7):
        r = proceso.stdout.readline().strip()
        if r:
            print("  " + r)

proceso.stdin.close()
proceso.wait()
