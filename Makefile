target: *.beam

*.beam: *.erl
	erlc *.erl

clean:
	rm -rf *.beam *.dump *~
