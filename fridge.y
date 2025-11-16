%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

extern int yylex(void);
extern int yyparse(void);

/* Use uma variável própria para o arquivo de saída (evita conflito com yyout do Flex) */
extern FILE *yyin;
FILE *outasm = NULL;

void yyerror(const char *s);

/* tabela de símbolos e helpers... */
typedef struct Sym {
    char *name;
    int addr; /* memória (endereço) */
    struct Sym *next;
} Sym;

Sym *symtable = NULL;
int next_addr = 0;


Sym *sym_find(const char *name) {
    for (Sym *s = symtable; s; s = s->next)
        if (strcmp(s->name, name) == 0) return s;
    return NULL;
}

int sym_getaddr(const char *name) {
    Sym *s = sym_find(name);
    if (!s) {
        s = malloc(sizeof(Sym));
        s->name = strdup(name);
        s->addr = next_addr++;
        s->next = symtable;
        symtable = s;
    }
    return s->addr;
}

void emit(const char *fmt, ...) {
    if (!outasm) {
        fprintf(stderr, "emit: outasm não está aberto\n");
        return;
    }
    va_list ap;
    va_start(ap, fmt);
    vfprintf(outasm, fmt, ap);
    fprintf(outasm, "\n");
    va_end(ap);
}


/* generate code to evaluate an expression and leave result on VM stack */
int temp_counter = 0;
int current_if_id = 0;
int current_while_id = 0;
void gen_expr_to_stack(); /* prototype */

%}

%union {
    int num;
    char *str;
    int boolean;
}

%token <str> IDENT
%token <num> NUMBER
%token <str> STRING
%token <boolean> BOOLEAN

%token VAR IF ELSE WHILE
%token SET_TEMP SET_MODE ADD_ITEM REMOVE_ITEM PRINT

%token EQ NEQ LE GE

%left '+' '-'
%left '*' '/'
%nonassoc EQ NEQ '<' '>' LE GE

%type <num> expression

%%

program:
    /* empty */
    | program declaracao
    ;

declaracao:
      atribuicao
    | condicional
    | laco_while
    | comando
    ;

atribuicao:
      VAR IDENT '=' expression ';'  {
                                        int addr = sym_getaddr($2);
                                        /* expression already pushed result onto stack; store into addr */
                                        emit("POP R0");
                                        emit("STORE R0, VAR_%d   ; %s", addr, $2);
                                        free($2);
                                    }
    | IDENT '=' expression ';' {
                                        int addr = sym_getaddr($1);
                                        emit("POP R0");
                                        emit("STORE R0, VAR_%d   ; %s", addr, $1);
                                        free($1);
                                    }
    ;

condicional:
    IF '(' expression ')' {
        /* Evaluate condition first, result is on stack */
        current_if_id = ++temp_counter;
        emit("POP R0");
        emit("CMP R0, 0");
        emit("JE ELSE_%d", current_if_id);
    } bloco {
        /* Then block executed, now jump to end */
        emit("JMP ENDIF_%d", current_if_id);
        emit("LABEL ELSE_%d", current_if_id);
        emit("LABEL ENDIF_%d", current_if_id);
    }
    | IF '(' expression ')' {
        /* Evaluate condition first */
        current_if_id = ++temp_counter;
        emit("POP R0");
        emit("CMP R0, 0");
        emit("JE ELSE_%d", current_if_id);
    } bloco ELSE {
        /* Then block done, jump to end */
        emit("JMP ENDIF_%d", current_if_id);
        emit("LABEL ELSE_%d", current_if_id);
    } bloco {
        /* Else block done */
        emit("LABEL ENDIF_%d", current_if_id);
    }
    ;

laco_while:
    WHILE {
        /* Start of while loop - emit label */
        current_while_id = ++temp_counter;
        emit("LABEL WHILE_START_%d", current_while_id);
    } '(' expression ')' {
        /* Condition evaluated, result on stack */
        emit("POP R0");
        emit("CMP R0, 0");
        emit("JE WHILE_END_%d", current_while_id);
    } bloco {
        /* Body executed, jump back to start */
        emit("JMP WHILE_START_%d", current_while_id);
        emit("LABEL WHILE_END_%d", current_while_id);
    }
    ;

bloco:
    '{' { } bloco_interior '}' ;

bloco_interior:
    /* empty */
    | bloco_interior declaracao
    ;

comando:
      SET_TEMP '(' expression ')' ';' {
            emit("POP R0");
            emit("SET_TEMP R0");
      }
    | SET_MODE '(' IDENT ')' ';' {
            /* mode is identifier token (TURBO/ECO/NORMAL or variable) */
            emit("SET_MODE %s", $3);
            free($3);
      }
    | ADD_ITEM '(' STRING ')' ';' {
            emit("ADD_ITEM \"%s\"", $3);
            free($3);
      }
    | REMOVE_ITEM '(' STRING ')' ';' {
            emit("REMOVE_ITEM \"%s\"", $3);
            free($3);
      }
    | PRINT '(' STRING ')' ';' {
            emit("PRINT \"%s\"", $3);
            free($3);
      }
    ;

expression:
      NUMBER {
        emit("PUSH %d", $1);
        $$ = $1;
      }
    | IDENT {
        /* Check if it's a sensor (readonly) */
        if (strcmp($1, "DOOR") == 0 || strcmp($1, "ENERGY") == 0 || strcmp($1, "OUTSIDE_TEMP") == 0) {
            emit("CHECK_SENSOR %s", $1);
            emit("PUSH R0");
        } else {
            int addr = sym_getaddr($1);
            emit("LOAD R0, VAR_%d   ; %s", addr, $1);
            emit("PUSH R0");
        }
        free($1);
        $$ = 0;
      }
    | BOOLEAN {
        emit("PUSH %d", $1 ? 1 : 0);
        $$ = $1;
      }
    | '(' expression ')' { /* parentheses already evaluated */ $$ = $2; }
    | expression '+' expression {
        /* note: both sides push results; we just emit an ADD */
        emit("POP R1");
        emit("POP R0");
        emit("ADD R0, R1");
        emit("PUSH R0");
      }
    | expression '-' expression {
        emit("POP R1");
        emit("POP R0");
        emit("SUB R0, R1");
        emit("PUSH R0");
      }
    | expression '*' expression {
        emit("POP R1");
        emit("POP R0");
        emit("MUL R0, R1");
        emit("PUSH R0");
      }
    | expression '/' expression {
        emit("POP R1");
        emit("POP R0");
        emit("DIV R0, R1");
        emit("PUSH R0");
      }
    | expression EQ expression {
        int id = ++temp_counter;
        emit("POP R1");
        emit("POP R0");
        emit("CMP R0, R1");
        emit("JE EQ_TRUE_%d", id);
        emit("PUSH 0");  /* false */
        emit("JMP EQ_DONE_%d", id);
        emit("LABEL EQ_TRUE_%d", id);
        emit("PUSH 1");  /* true */
        emit("LABEL EQ_DONE_%d", id);
      }
    | expression NEQ expression {
        int id = ++temp_counter;
        emit("POP R1");
        emit("POP R0");
        emit("CMP R0, R1");
        emit("JNE NEQ_TRUE_%d", id);
        emit("PUSH 0");  /* false */
        emit("JMP NEQ_DONE_%d", id);
        emit("LABEL NEQ_TRUE_%d", id);
        emit("PUSH 1");  /* true */
        emit("LABEL NEQ_DONE_%d", id);
      }
    | expression '<' expression {
        int id = ++temp_counter;
        emit("POP R1");
        emit("POP R0");
        emit("CMP R0, R1");
        emit("JL LT_TRUE_%d", id);
        emit("PUSH 0");  /* false */
        emit("JMP LT_DONE_%d", id);
        emit("LABEL LT_TRUE_%d", id);
        emit("PUSH 1");  /* true */
        emit("LABEL LT_DONE_%d", id);
      }
    | expression '>' expression {
        int id = ++temp_counter;
        emit("POP R1");
        emit("POP R0");
        emit("CMP R0, R1");
        emit("JG GT_TRUE_%d", id);
        emit("PUSH 0");  /* false */
        emit("JMP GT_DONE_%d", id);
        emit("LABEL GT_TRUE_%d", id);
        emit("PUSH 1");  /* true */
        emit("LABEL GT_DONE_%d", id);
      }
    | expression LE expression {
        int id = ++temp_counter;
        emit("POP R1");
        emit("POP R0");
        emit("CMP R0, R1");
        emit("JLE LE_TRUE_%d", id);
        emit("PUSH 0");  /* false */
        emit("JMP LE_DONE_%d", id);
        emit("LABEL LE_TRUE_%d", id);
        emit("PUSH 1");  /* true */
        emit("LABEL LE_DONE_%d", id);
      }
    | expression GE expression {
        int id = ++temp_counter;
        emit("POP R1");
        emit("POP R0");
        emit("CMP R0, R1");
        emit("JGE GE_TRUE_%d", id);
        emit("PUSH 0");  /* false */
        emit("JMP GE_DONE_%d", id);
        emit("LABEL GE_TRUE_%d", id);
        emit("PUSH 1");  /* true */
        emit("LABEL GE_DONE_%d", id);
      }
    ;

%%

/* C prologue/aux */
#include <stdarg.h>

extern FILE *yyout;

void yyerror(const char *s) {
    fprintf(stderr, "Erro: %s\n", s);
}

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "Uso: %s fonte.fridge\n", argv[0]);
        return 1;
    }
    FILE *in = fopen(argv[1], "r");
    if (!in) { perror("fopen"); return 1; }
    outasm = fopen("output.asm", "w");
    if (!outasm) { perror("fopen output"); return 1; }
    extern FILE *yyin;
    yyin = in;
    yyparse();

    /* Emit HALT at the end */
    emit("HALT");
    
    /* optional: dump symbol table as comments */
    fprintf(outasm, "\n; Symbol table:\n");
    for (Sym *s = symtable; s; s = s->next) {
        fprintf(outasm, "; VAR_%d = %s\n", s->addr, s->name);
    }

    fclose(in);
    fclose(outasm);
    printf("Geração concluída -> output.asm\n");
    return 0;
}
