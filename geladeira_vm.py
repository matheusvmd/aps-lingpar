#!/usr/bin/env python3
"""
GeladeiraVM - Emulador da Máquina Virtual da Geladeira
Simula uma geladeira inteligente com registradores, memória e sensores.
"""

import sys
import re
from typing import Dict, List, Optional, Tuple

class GeladeiraVM:
    """Máquina Virtual da Geladeira"""
    
    def __init__(self):
        # Registradores (writable)
        self.registers = {
            'TEMP': 4,      # temperatura interna (°C)
            'MODO': 'NORMAL'  # modo de operação
        }
        
        # Memória para variáveis
        self.memory: Dict[int, int] = {}
        
        # Lista de alimentos
        self.items: List[str] = []
        
        # Sensores (readonly)
        self.sensors = {
            'DOOR': False,      # porta aberta/fechada
            'ENERGY': 50,       # consumo de energia (W)
            'OUTSIDE_TEMP': 25  # temperatura ambiente (°C)
        }
        
        # Registradores da VM (R0, R1 para operações)
        self.R0 = 0
        self.R1 = 0
        
        # Pilha
        self.stack: List[int] = []
        
        # Instruções do programa
        self.instructions: List[Tuple[str, ...]] = []
        
        # Labels (nome -> índice da instrução)
        self.labels: Dict[str, int] = {}
        
        # Program counter
        self.pc = 0
        
        # Flags de comparação
        self.flags = {
            'equal': False,
            'less': False,
            'greater': False
        }
        
        # Output
        self.output: List[str] = []
    
    def load_program(self, asm_file: str):
        """Carrega um programa assembly"""
        with open(asm_file, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        # Processa todas as linhas em uma única passagem
        for line in lines:
            line = line.strip()
            # Remove comentários
            if ';' in line:
                line = line.split(';')[0].strip()
            if not line or line.startswith(';'):
                continue
            
            # Verifica se é label
            if line.startswith('LABEL '):
                label_name = line[6:].strip()
                self.labels[label_name] = len(self.instructions)
            else:
                # Parseia instrução (remove vírgulas, preserva strings entre aspas)
                parts = []
                i = 0
                while i < len(line):
                    if line[i] == '"':
                        # Encontrou string, pega tudo até a próxima aspas
                        end = line.find('"', i + 1)
                        if end != -1:
                            parts.append(line[i:end+1])
                            i = end + 1
                        else:
                            parts.append(line[i:])
                            break
                    elif line[i].isspace():
                        i += 1
                    else:
                        # Pega próximo token
                        start = i
                        while i < len(line) and not line[i].isspace() and line[i] != ',':
                            i += 1
                        token = line[start:i].rstrip(',')
                        if token:
                            parts.append(token)
                        if i < len(line) and line[i] == ',':
                            i += 1
                
                if parts:
                    self.instructions.append(tuple(parts))
        
        print(f"Programa carregado: {len(self.instructions)} instruções, {len(self.labels)} labels")
    
    def push(self, value: int):
        """Empilha um valor"""
        self.stack.append(value)
    
    def pop(self) -> int:
        """Desempilha um valor"""
        if not self.stack:
            raise RuntimeError("Stack underflow!")
        return self.stack.pop()
    
    def get_value(self, operand: str) -> int:
        """Obtém o valor de um operando (número, registrador, variável)"""
        # Número literal
        if operand.isdigit() or (operand.startswith('-') and operand[1:].isdigit()):
            return int(operand)
        
        # Registrador
        if operand == 'R0':
            return self.R0
        if operand == 'R1':
            return self.R1
        
        # Variável na memória (VAR_X)
        if operand.startswith('VAR_'):
            var_id = int(operand[4:])
            return self.memory.get(var_id, 0)
        
        return 0
    
    def set_value(self, operand: str, value: int):
        """Define o valor de um operando"""
        if operand == 'R0':
            self.R0 = value
        elif operand == 'R1':
            self.R1 = value
        elif operand.startswith('VAR_'):
            var_id = int(operand[4:])
            self.memory[var_id] = value
    
    def execute_instruction(self, instr: Tuple[str, ...]) -> Optional[str]:
        """Executa uma instrução. Retorna 'HALT' se deve parar."""
        op = instr[0]
        
        if op == 'PUSH':
            if len(instr) > 1:
                value = self.get_value(instr[1])
                self.push(value)
        
        elif op == 'POP':
            if len(instr) > 1:
                value = self.pop()
                self.set_value(instr[1], value)
        
        elif op == 'LOAD':
            if len(instr) >= 3:
                dest = instr[1]
                src = instr[2]
                value = self.get_value(src)
                self.set_value(dest, value)
        
        elif op == 'STORE':
            if len(instr) >= 3:
                src = instr[1]  # R0
                dest = instr[2]  # VAR_X
                value = self.get_value(src)
                # STORE armazena o valor de src em dest
                if dest.startswith('VAR_'):
                    var_id = int(dest[4:].split()[0])  # Remove comentários se houver
                    self.memory[var_id] = value
                else:
                    self.set_value(dest, value)
        
        elif op == 'ADD':
            if len(instr) >= 3:
                dest = instr[1]
                src = instr[2]
                val1 = self.get_value(dest)
                val2 = self.get_value(src)
                self.set_value(dest, val1 + val2)
        
        elif op == 'SUB':
            if len(instr) >= 3:
                dest = instr[1]
                src = instr[2]
                val1 = self.get_value(dest)
                val2 = self.get_value(src)
                self.set_value(dest, val1 - val2)
        
        elif op == 'MUL':
            if len(instr) >= 3:
                dest = instr[1]
                src = instr[2]
                val1 = self.get_value(dest)
                val2 = self.get_value(src)
                self.set_value(dest, val1 * val2)
        
        elif op == 'DIV':
            if len(instr) >= 3:
                dest = instr[1]
                src = instr[2]
                val1 = self.get_value(dest)
                val2 = self.get_value(src)
                if val2 == 0:
                    raise RuntimeError("Division by zero!")
                self.set_value(dest, val1 // val2)
        
        elif op == 'CMP':
            if len(instr) >= 3:
                val1 = self.get_value(instr[1])
                val2 = self.get_value(instr[2])
                self.flags['equal'] = (val1 == val2)
                self.flags['less'] = (val1 < val2)
                self.flags['greater'] = (val1 > val2)
        
        elif op == 'JE':  # Jump if equal
            if len(instr) > 1:
                label = instr[1]
                if self.flags['equal']:
                    if label in self.labels:
                        self.pc = self.labels[label]
                        return 'JUMP'
        
        elif op == 'JNE':  # Jump if not equal
            if len(instr) > 1:
                label = instr[1]
                if not self.flags['equal']:
                    if label in self.labels:
                        self.pc = self.labels[label]
                        return 'JUMP'
        
        elif op == 'JL':  # Jump if less
            if len(instr) > 1:
                label = instr[1]
                if self.flags['less']:
                    if label in self.labels:
                        self.pc = self.labels[label]
                        return 'JUMP'
        
        elif op == 'JG':  # Jump if greater
            if len(instr) > 1:
                label = instr[1]
                if self.flags['greater']:
                    if label in self.labels:
                        self.pc = self.labels[label]
                        return 'JUMP'
        
        elif op == 'JLE':  # Jump if less or equal
            if len(instr) > 1:
                label = instr[1]
                if self.flags['less'] or self.flags['equal']:
                    if label in self.labels:
                        self.pc = self.labels[label]
                        return 'JUMP'
        
        elif op == 'JGE':  # Jump if greater or equal
            if len(instr) > 1:
                label = instr[1]
                if self.flags['greater'] or self.flags['equal']:
                    if label in self.labels:
                        self.pc = self.labels[label]
                        return 'JUMP'
        
        elif op == 'JMP':  # Jump unconditional
            if len(instr) > 1:
                label = instr[1]
                if label in self.labels:
                    self.pc = self.labels[label]
                    return 'JUMP'
        
        elif op == 'SET_TEMP':
            if len(instr) > 1:
                temp = self.get_value(instr[1])
                self.registers['TEMP'] = temp
                print(f"🌡️  Temperatura definida para {temp}°C")
        
        elif op == 'SET_MODE':
            if len(instr) > 1:
                mode = instr[1]
                if mode in ['NORMAL', 'ECO', 'TURBO']:
                    self.registers['MODO'] = mode
                    print(f"⚙️  Modo alterado para {mode}")
        
        elif op == 'ADD_ITEM':
            if len(instr) > 1:
                # Remove aspas se houver
                item = instr[1].strip('"')
                self.items.append(item)
                print(f"➕ Item adicionado: {item}")
        
        elif op == 'REMOVE_ITEM':
            if len(instr) > 1:
                item = instr[1].strip('"')
                if item in self.items:
                    self.items.remove(item)
                    print(f"➖ Item removido: {item}")
                else:
                    print(f"⚠️  Item não encontrado: {item}")
        
        elif op == 'CHECK_SENSOR':
            if len(instr) > 1:
                sensor = instr[1]
                if sensor == 'DOOR':
                    self.R0 = 1 if self.sensors['DOOR'] else 0
                elif sensor == 'ENERGY':
                    self.R0 = self.sensors['ENERGY']
                elif sensor == 'OUTSIDE_TEMP':
                    self.R0 = self.sensors['OUTSIDE_TEMP']
        
        elif op == 'PRINT':
            if len(instr) > 1:
                msg = instr[1].strip('"')
                self.output.append(msg)
                print(f"📢 {msg}")
        
        elif op == 'HALT':
            return 'HALT'
        
        elif op == 'LABEL':
            # Labels são processados na primeira passagem, ignorar aqui
            pass
        
        return None
    
    def run(self, max_steps: int = 10000, verbose: bool = False):
        """Executa o programa"""
        print("=" * 50)
        print("🧊 GeladeiraVM - Iniciando execução")
        print("=" * 50)
        
        step_count = 0
        
        while self.pc < len(self.instructions) and step_count < max_steps:
            instr = self.instructions[self.pc]
            
            if verbose:
                print(f"[{self.pc}] {' '.join(instr)}")
            
            result = self.execute_instruction(instr)
            
            if result == 'HALT':
                print("\n🛑 Programa encerrado (HALT)")
                break
            
            if result != 'JUMP':
                self.pc += 1
            
            step_count += 1
        
        if step_count >= max_steps:
            print(f"\n⚠️  Limite de {max_steps} passos atingido!")
        
        print("\n" + "=" * 50)
        print("📊 Estado Final:")
        print("=" * 50)
        print(f"Temperatura: {self.registers['TEMP']}°C")
        print(f"Modo: {self.registers['MODO']}")
        print(f"Items: {self.items}")
        print(f"Memória: {self.memory}")
        print(f"Passos executados: {step_count}")
        print("=" * 50)


def main():
    if len(sys.argv) < 2:
        print("Uso: python3 geladeira_vm.py <arquivo.asm> [--verbose]")
        sys.exit(1)
    
    asm_file = sys.argv[1]
    verbose = '--verbose' in sys.argv or '-v' in sys.argv
    
    vm = GeladeiraVM()
    
    # Configurar sensores (pode ser modificado)
    vm.sensors['DOOR'] = True  # Porta aberta para teste
    
    try:
        vm.load_program(asm_file)
        vm.run(verbose=verbose)
    except Exception as e:
        print(f"❌ Erro durante execução: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()

