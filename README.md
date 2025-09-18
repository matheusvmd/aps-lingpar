# ❄️ FridgeLang

## Entrega #1 – Linguagem estruturada segundo a EBNF  

### Máquina-alvo escolhida: **GeladeiraVM**

A **GeladeiraVM** simula uma geladeira inteligente, equipada com registradores, sensores e comandos básicos para controle de temperatura, armazenamento de alimentos e economia de energia.  

A proposta é criar uma linguagem de alto nível (**FridgeLang**) que gera código para essa máquina, permitindo escrever programas que automatizam tarefas da geladeira.  

---

## 🧊 GeladeiraVM – Modelo

### Registradores
- `TEMP` — temperatura interna (°C).  
- `MODO` — modo de operação (`NORMAL`, `ECO`, `TURBO`).  

### Memória
- Lista de alimentos armazenados (`ITEMS`).  
- Histórico de aberturas da porta.  

### Sensores (somente leitura)
- `DOOR` — estado da porta (`true`/`false`).  
- `ENERGY` — nível de consumo atual (W).  
- `OUTSIDE_TEMP` — temperatura ambiente (°C).  

### Instruções primitivas
- `SET_TEMP n` — define a temperatura interna para `n`.  
- `SET_MODE x` — altera o modo de operação.  
- `ADD_ITEM x` — adiciona alimento à memória.  
- `REMOVE_ITEM x` — remove alimento.  
- `CHECK_DOOR` — lê o estado da porta.  
- `PRINT x` — exibe uma mensagem.  
- `HALT` — encerra a execução.  

---

## 💡 FridgeLang – Gramática em EBNF

```ebnf
programa        = { declaracao } ;

declaracao      = atribuicao | condicional | laco_while | comando ;

atribuicao      = "var" identificador "=" expressao ";" 
                | identificador "=" expressao ";" ;

condicional     = "if" "(" expressao ")" bloco [ "else" bloco ] ;
laco_while      = "while" "(" expressao ")" bloco ;

bloco           = "{" { declaracao } "}" ;

comando         = "set_temp" "(" expressao ")" ";"
                | "set_mode" "(" identificador ")" ";"
                | "add_item" "(" string ")" ";"
                | "remove_item" "(" string ")" ";"
                | "print" "(" string ")" ";" ;

expressao       = termo { operador termo } ;
termo           = identificador | numero | string | booleano | "(" expressao ")" ;

operador        = "+" | "-" | "*" | "/" | "==" | "!=" | "<" | "<=" | ">" | ">=" ;

identificador   = letra { letra | digito | "_" } ;
numero          = digito { digito } ;
string          = "\"" { caractere } "\"" ;
booleano        = "true" | "false" ;

```
## 📖 Exemplo de programa em FridgeLang

```gel
var milk = 1;
var meat = 2;

if (DOOR == true) {
    print("⚠️ Feche a porta!");
}

while (meat > 0) {
    set_temp(2);
    set_mode(TURBO);
    meat = meat - 1;
    add_item("carne preparada");
}
```
## 🔍 Explicação do exemplo

### Declaração de variáveis
- `milk` e `meat` armazenam quantidades de alimentos.

### Condicional
- Testa se a porta (`DOOR`) está aberta.  
- Caso verdadeiro, imprime uma mensagem de aviso.

### Laço `while`
Enquanto houver carne (`meat > 0`), executa:
- Ajuste da temperatura (`set_temp(2)`).
- Ativação do modo `TURBO`.
- Consumo da carne (`meat = meat - 1`).
- Registro de um item preparado na memória da geladeira (`add_item`).

---

## 🚀 Possíveis usos da FridgeLang

- **Ensino de compiladores** → gramática clara, simples e extensível.  
- **Simulação de dispositivos inteligentes** → modela um eletrodoméstico cotidiano.  
- **Extensibilidade** → é fácil adicionar comandos novos (ex.: `defrost`, `energy_save`).  
- **Didática** → mostra estruturas de controle (`if/else`, `while`) de forma lúdica.  

