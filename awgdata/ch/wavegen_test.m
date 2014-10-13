t=-199:200;
rads=t*2*pi/1000;
sn=sin(rads);
sc=sinc(rads);
zz=t*0;

swrite("sin.dat",    cat(1,sn,sn,sn,sn,sn)*32767);
swrite("pulse1.dat", cat(1,sc,zz,zz,zz,zz)*32767);
swrite("pulse2.dat", cat(1,zz,sc,zz,zz,zz)*32767);
swrite("pulse3.dat", cat(1,zz,zz,sc,zz,zz)*32767);
swrite("saw.dat",    cat(1,t,t,t,t,t)*32767/200);

