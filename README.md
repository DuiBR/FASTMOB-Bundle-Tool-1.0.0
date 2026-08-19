# 🚀 FASTMOB Bundle Tool

Ferramenta automatizada para **analisar, modificar e validar arquivos `index.android.bundle`**, incluindo bundles compilados com **Hermes Bytecode (HBC)**.

O FASTMOB Bundle Tool foi criado para simplificar tarefas que normalmente exigiriam vários comandos manuais, oferecendo um **menu interativo**, instalação automática de dependências, backups e validação do bundle.

---

## ✨ Principais recursos

* 🔎 Detecta automaticamente se o bundle utiliza **Hermes**
* 🧠 Identifica automaticamente a versão **HBC**
* 🔗 Alteração simplificada de URLs
* ✏️ Alteração de textos e strings
* 🔢 Alteração de valores armazenados como string
* 🆔 Alteração por **String ID**
* 🔍 Pesquisa de textos e URLs
* 🔗 Localização de referências com **XREF**
* 📜 Decompilação do bundle
* 🧩 Decompilação individual de funções
* 🛠️ Disassembly Hermes
* ⚙️ Edição avançada utilizando **HASM**
* ✅ Validação automática após alterações
* 🔄 Comparação entre original e modificado
* 💾 Backup automático
* ♻️ Restauração de versões anteriores
* 📦 Exportação do bundle final
* 📋 Histórico de alterações

---

## 🖥️ Sistemas suportados

O instalador detecta automaticamente o sistema e instala as dependências necessárias.

Compatível com:

* 🐧 Ubuntu
* 🐧 Debian
* 🐧 Kali Linux
* 🐧 Linux Mint
* 🐧 Fedora
* 🐧 Rocky Linux
* 🐧 AlmaLinux
* 🐧 Oracle Linux
* 🐧 Arch Linux
* 🐧 Manjaro
* 🐧 Alpine Linux
* 🐧 openSUSE
* 📱 Termux
* 🍎 macOS
* 🪟 WSL

---

# ⚡ Instalação rápida

Execute apenas este comando:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/DuiBR/FASTMOB-Bundle-Tool-1.0.0/main/fastmob-bundle-tool.sh)
```

O instalador irá automaticamente:

```text
✅ Detectar seu sistema
✅ Detectar a arquitetura
✅ Instalar dependências
✅ Instalar Rust/Cargo se necessário
✅ Instalar/compilar hermes-decomp
✅ Preparar o ambiente
✅ Abrir o menu principal
```

---

## 🔁 Abrir novamente

Após a instalação, basta executar:

```bash
fastmob-bundle
```

---

# 📂 Importando o bundle

Tenha em mãos o arquivo:

```text
index.android.bundle
```

No menu principal escolha:

```text
[1] Selecionar/importar index.android.bundle
```

Informe o caminho do arquivo.

Exemplo:

```text
/root/index.android.bundle
```

A ferramenta criará automaticamente uma cópia protegida do original.

---

# 🔗 Alterando uma URL

No menu escolha:

```text
[4] Alterar URL/link
```

Será solicitado:

```text
Link antigo:
```

Exemplo:

```text
https://xc.productgid.com/api/
```

Depois:

```text
Link novo:
```

Exemplo:

```text
https://xm.fastmob.app.br/api/
```

A ferramenta verifica automaticamente:

* 🔎 se a URL existe;
* 📏 tamanho em bytes;
* 🧠 versão Hermes/HBC;
* 📦 estrutura da string;
* 💾 backup anterior;
* ✅ integridade após a alteração.

---

# ✏️ Alterando textos

Escolha:

```text
[5] Alterar texto/string
```

Informe:

```text
Texto antigo
Texto novo
```

A ferramenta tentará realizar a alteração de forma segura dentro da tabela de strings Hermes.

---

# 🔍 Procurando URLs

Escolha:

```text
[3] Listar URLs encontradas
```

A ferramenta mostrará as URLs existentes no bundle para facilitar a análise.

---

# 🧠 Análise do Hermes

Escolha:

```text
[2] Analisar bundle / identificar HBC
```

Serão exibidas informações como:

```text
Hermes detectado
Versão HBC
Quantidade de funções
Quantidade de strings
Tamanho do bundle
```

O FASTMOB Bundle Tool utiliza o **hermes-decomp**, compatível com várias versões de Hermes Bytecode.

---

# 🔗 XREF

Para descobrir onde determinada URL ou string é utilizada:

```text
[9] Localizar referências (XREF)
```

Digite a string desejada.

Exemplo:

```text
https://servidor.com/api/
```

A ferramenta tentará identificar as funções Hermes que utilizam aquela informação.

---

# 🧩 Edição avançada

Para modificações de lógica existem opções avançadas:

```text
[11] Decompilar uma função
[12] Disassembly de uma função
[13] Editar função via HASM
```

Fluxo:

```text
String / URL
      ↓
     XREF
      ↓
 Function ID
      ↓
  Decompile
      ↓
   Disasm
      ↓
    HASM
      ↓
Patch Function
      ↓
 Validação
```

⚠️ Utilize essas funções somente se souber exatamente qual lógica deseja modificar.

---

# 💾 Backups automáticos

Antes das alterações, o FASTMOB Bundle Tool mantém cópias de segurança.

Estrutura utilizada:

```text
~/.fastmob-bundle-tool/

├── original/
├── current/
├── output/
├── analysis/
├── backups/
├── tools/
└── logs/
```

O arquivo original permanece preservado.

---

# ♻️ Restaurar alterações

Para voltar ao último backup:

```text
[16] Restaurar último backup
```

Para voltar completamente ao bundle original:

```text
[17] Restaurar bundle original
```

---

# 📦 Exportar bundle final

Após finalizar as alterações escolha:

```text
[18] Exportar index.android.bundle final
```

Depois substitua no APK:

```text
assets/index.android.bundle
```

⚠️ Não abra e salve bundles Hermes usando editores de texto comuns.

---

# 🧠 VPS com pouca memória

O instalador verifica automaticamente os recursos do sistema.

Em máquinas com pouca RAM, ele pode:

* limitar a compilação;
* utilizar apenas 1 job;
* preparar Swap quando necessário.

Isso reduz o risco de travamentos durante a compilação do `hermes-decomp`.

---

# 🛡️ Segurança

O FASTMOB Bundle Tool:

* preserva o bundle original;
* cria backups;
* valida alterações;
* evita sobrescrever diretamente o arquivo original;
* cancela alterações quando identifica risco de corrupção.

Mesmo assim, sempre mantenha uma cópia do APK original.

---

# 📋 Menu principal

```text
[1]  Selecionar/importar index.android.bundle
[2]  Analisar bundle / identificar HBC
[3]  Listar URLs encontradas
[4]  Alterar URL/link
[5]  Alterar texto/string
[6]  Alterar valor armazenado como string
[7]  Alterar string pelo ID Hermes
[8]  Pesquisar texto/URL/string
[9]  Localizar referências (XREF)

[10] Decompilar bundle completo
[11] Decompilar uma função
[12] Disassembly de uma função
[13] Editar função via HASM

[14] Validar bundle atual
[15] Comparar atual com original
[16] Restaurar último backup
[17] Restaurar bundle original
[18] Exportar index.android.bundle final
[19] Histórico de alterações
[20] Status do sistema/ferramentas
```

---

# 🧰 Ferramentas utilizadas

O projeto utiliza principalmente:

* 🔧 Bash
* 🦀 Rust / Cargo
* 🧠 Hermes Decomp
* 🐍 Python
* 🔍 Binutils
* 🌐 cURL / wget

As dependências são instaladas automaticamente sempre que possível.

---

# ⚠️ Aviso

Utilize esta ferramenta apenas em aplicativos, bundles e projetos que você tenha autorização para analisar ou modificar.

Modificações incorretas no bytecode podem causar:

```text
❌ Crash na inicialização
❌ Tela preta
❌ Erros Hermes
❌ Falhas em funções específicas
```

Por isso a ferramenta mantém backups e validações automáticas.

---

# 👨‍💻 Projeto

**FASTMOB Bundle Tool**

Repositório:

```text
https://github.com/DuiBR/FASTMOB-Bundle-Tool-1.0.0
```

---

## ⭐ Gostou do projeto?

Se a ferramenta foi útil, deixe uma ⭐ no repositório.

Isso ajuda a manter o projeto ativo e receber novas melhorias.

---

### 🚀 Instalação em uma linha

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/DuiBR/FASTMOB-Bundle-Tool-1.0.0/main/fastmob-bundle-tool.sh)
```

Depois:

```bash
fastmob-bundle
```

**FASTMOB Bundle Tool — análise e edição de Hermes Bytecode de forma simples e automatizada.** 🚀
