function swrite(fname, xx)
	fp = fopen(fname, "w");
	fwrite(fp,xx,"short");
	fclose(fp);
endfunction

