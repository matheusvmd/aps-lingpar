all: fridge_compiler

fridge_compiler: fridge.tab.c lex.yy.c
	gcc -o fridge_compiler fridge.tab.c lex.yy.c -ll

fridge.tab.c fridge.tab.h: fridge.y
	bison -d fridge.y

lex.yy.c: fridge.l fridge.tab.h
	flex fridge.l

clean:
	rm -f fridge.tab.c fridge.tab.h lex.yy.c fridge_compiler output.asm
