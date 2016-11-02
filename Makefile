test:
	prove -Ilib -Ilocal/lib t
	perl bin/potracheno.psgi --list
