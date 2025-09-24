# **🚀 Guia de Instalação – Servidor de Backup com Rest Server no FreeBSD**

Este guia descreve como configurar um **servidor de backup** para armazenamento de backups **Restic** usando **Rest Server** 

---

## **🙏 Agradecimentos**

O **Rest Server** é mantido pela equipe do [**Restic**](https://github.com/restic/rest-server).  
Meus agradecimentos aos criadores pelo excelente trabalho que torna esta solução possível.

Eu, **Leonardo Ribeiro**, adaptei o script `install.sh` para ser totalmente compatível com **FreeBSD**.  
Repositório adaptado: <https://github.com/pmbatatais/backup-server.git>

---

## **⚙️ Ambiente utilizado**

- **Sistema operacional:** FreeBSD 14.3
- **Servidor de backup:** Repositório REST Server. [Leia a página oficial](https://github.com/restic/rest-server)
- **Armazenamento:**
  - 2 discos de 1TB em espelhamento (mirror) via ZFS
  - Pool ZFS: `zroot`
  - Dataset: `zroot/rest-server`
  - Mountpoint: `/mnt/backups/rest-server`
  - Compressão: `lz4`

---

## **💾 Sobre o Servidor REST Server e Backup com Restic**

O **REST Server** é um **servidor HTTP de alta performance** que implementa a **API REST do Restic**, permitindo que clientes Restic façam backups remotos de forma segura e eficiente usando a URL `rest`:

O **Restic** é uma ferramenta de backup moderna e confiável, que oferece:

- 🔒 **Criptografia ponta-a-ponta**: os dados são criptografados no cliente antes de serem enviados, garantindo que ninguém consiga acessá-los sem a chave.
- 📦 **Deduplicação de dados**: arquivos repetidos não são duplicados, economizando espaço em disco.

Combinando **REST Server + Restic**, você cria um **servidor de backup seguro, centralizado e eficiente**, pronto para receber dados de clientes confiáveis.

---

## **📦 Instalação passo a passo**

### **1️⃣ Instalar o Git**

No FreeBSD, use:

```sh
sudo pkg install -y git
```

### **2️⃣ Clonar o repositório**

```sh
git clone https://github.com/pmbatatais/backup-server.git && cd backup-server
```

### **3️⃣ Preparar o script de instalação**

Dê permissão de execução ao script:

```shell
sudo chmod +x install.sh
```

### **4️⃣ Criar o dataset ZFS para os backups**

Se ainda não tiver criado o dataset, faça o seguinte:

```
# Criar dataset zfs
sudo zfs create -o mountpoint=/mnt/backups/rest-server -o compression=lz4 zroot/rest-server

# Verificar se o dataset está montado corretamente
sudo zfs list
```

💡 **Dica:** Este dataset será o diretório onde os `Restic-Backups` serão armazenados.

### **5️⃣ Executar a instalação**

Rode o script adaptado para FreeBSD:

```shell
sudo sh install.sh
```

> 📢 Observação: Executar `./install.sh` direto pode não funcionar em alguns ambientes. \
> 🤓 Use sempre `sh install.sh`.

Você também pode modificar o caminho do repositório e a porta TCP:

```shell
sudo sh install.sh --path=/backups/repo_restic --port=8081
```

### 6️⃣ **Dica Bônus: Usuário SFTP Somente Leitura**
> Para permitir que um técnico ou usuário visualize os repositórios do REST Server **sem alterar ou excluir nada**, siga este passo a passo:

#### 👥 6.1. Criar o grupo `sftpusers` (se ainda não existir)
```sh
sudo pw groupadd sftpusers
```

#### 👤 6.2. Criar o usuário e adicioná-lo ao grupo `sftpusers`

```sh
sudo pw useradd readonly -m -d /mnt/backups/rest-server -s /usr/sbin/nologin -G sftpusers
sudo passwd readonly
```
> - `readonly`: nome do usuário de exemplo  
> - `/mnt/backups/rest-server`: diretório dos repositórios  
> - `/usr/sbin/nologin`: impede login SSH interativo

#### 🔒 6.3. Configurar SSH para Chroot (enjaular o usuário)

No `/etc/ssh/sshd_config` adicione:

```conf
Match Group sftpusers
    ChrootDirectory %h
    ForceCommand internal-sftp
    AllowTcpForwarding no
    X11Forwarding no
```

> `%h` garante que o usuário fique **preso ao próprio diretório home**, sem acesso a outros diretórios do sistema

#### 📂 6.4. Ajustar permissões para leitura apenas

```sh
sudo chown -R root:sftpusers /mnt/backups/rest-server
sudo chmod -R 755 /mnt/backups/rest-server
```
> O usuário pode navegar e baixar arquivos, **mas não criar, alterar ou excluir**. \
> Subdiretórios devem seguir a mesma regra de propriedade `root:sftpusers`

#### ⚡ 6.5. Testar o acesso SFTP
```sh
sftp readonly@ip_do_servidor
```
> O usuário consegue visualizar e baixar arquivos, mas tentativas de escrita **serão negadas**.

### ✅ **Resumo:** Ideal para auditoria, consultas externas ou backups.  
> O usuário **fica seguro e enjaulado**, sem risco de modificar os repositórios do REST Server.

---

## **▶️ Uso do serviço**

- **Iniciar o serviço:**

```shell
sudo service rest_server start
```

- **Parar o serviço:**

```shell
sudo service rest_server stop
```

- **Verificar status:**

```shell
sudo service rest_server status
```

---

## **🔗 Referências**

- Projeto **Rest Server**: <https://github.com/restic/rest-server>
- Ferramenta de Backup **Restic**: <https://restic.net>
- Tudo sobre **ZFS**: <https://docs.freebsd.org/pt-br/books/handbook/zfs/>
- Repositório adaptado para FreeBSD: <https://github.com/pmbatatais/backup-server.git>

---

### 💡 Agora você tem um servidor de backup pronto para receber seus dados de forma segura e confiável!

✍️ Criado com dedicação por **Leonardo Ribeiro**  
