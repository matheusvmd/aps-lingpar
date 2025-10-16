%{
#include "fridge.tab.h"
#include <string.h>
#include <stdlib.h>

void yyerror(const char *s);
%}

%%

[ \t\r\n]+                     ; /* espaço em branco */

"var"                          return VAR;
"if"                           return IF;
"else"                         return ELSE;
"while"                        return WHILE;

"set_temp"                     return SET_TEMP;
"set_mode"                     return SET_MODE;
"add_item"                     return ADD_ITEM;
"remove_item"                  return REMOVE_ITEM;
"print"                        return PRINT;

"true"                         { yylval.boolean = 1; return BOOLEAN; }
"false"                        { yylval.boolean = 0; return BOOLEAN; }

"=="                           return EQ;
"!="                           return NEQ;
"<="                           return LE;
">="                           return GE;

"("                            return '(';
")"                            return ')';
"{"                            return '{';
"}"                            return '}';
";"                            return ';';
","                            return ',';
"="                            return '=';

"+"                            return '+';
"-"                            return '-';
"*"                            return '*';
"/"                            return '/';
"<"                            return '<';
">"                            return '>';

\"(\\.|[^\"])*\"               {
                                  // remove quotes
                                  char *s = strdup(yytext);
                                  int len = strlen(s);
                                  s[len-1] = '\0';
                                  char *ret = strdup(s+1);
                                  free(s);
                                  yylval.str = ret;
                                  return STRING;
                               }

[0-9]+                         {
                                  yylval.num = atoi(yytext);
                                  return NUMBER;
                               }

[A-Za-z_][A-Za-z0-9_]*         {
                                  yylval.str = strdup(yytext);
                                  return IDENT;
                               }

.                              { /* caractere desconhecido */ return yytext[0]; }

%%

int yywrap(void) { return 1; }
