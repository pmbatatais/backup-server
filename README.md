# **🚀 Guia de Instalação – Servidor de Backup com Rest Server + Restic no FreeBSD**

Este guia descreve como configurar um **servidor de backup** usando **Rest Server** e **Restic**, rodando em **FreeBSD 14.3**.

---

## **🙏 Agradecimentos**

O **Rest Server** é mantido pela equipe do [**Restic**](https://github.com/restic/rest-server).  
Meus agradecimentos aos criadores pelo excelente trabalho que torna esta solução possível.

Eu, **Leonardo Ribeiro**, adaptei o script `install.sh` para ser totalmente compatível com **FreeBSD**.  
Repositório adaptado: <https://github.com/pmbatatais/backup-server.git>

---

## **⚙️ Ambiente utilizado**

- **Sistema operacional:** FreeBSD 14.3
- **Tecnologia de backup:** [Restic](https://restic.net/)
- **Armazenamento:**
  - 2 discos de 1TB em espelhamento (mirror) via ZFS
  - Pool ZFS: `zroot`
  - Dataset: `zroot/rest-server`
  - Mountpoint: `/mnt/backups/rest-server`
  - Compressão: `lz4`

---

## **📦 Instalação passo a passo**

### **1️⃣ Instalar o Git**

No FreeBSD, use:

```shell
pkg install -y git
```

### **2️⃣ Clonar o repositório**

```shell
git clone https://github.com/pmbatatais/backup-server.git
cd backup-server
```

### **3️⃣ Preparar o script de instalação**

Dê permissão de execução ao script:

```shell
chmod +x install.sh
```

### **4️⃣ Criar o dataset ZFS para os backups**

Se ainda não tiver criado o dataset, faça o seguinte:

```
# Criar dataset zfs
zfs create -o mountpoint=/mnt/backups/rest-server -o compression=lz4 zroot/rest-server

# Verificar se o dataset está montado corretamente
zfs list
```

💡 **Dica:** Este dataset será o diretório onde os backups `Rest` serão armazenados.

### **5️⃣ Executar a instalação**

Rode o script adaptado para FreeBSD:

```shell
sh install.sh
```

> ⚠️ Observação: Executar `./install.sh` direto pode não funcionar em alguns ambientes. \
> Use sempre `sh install.sh`.

O script instalará o **Rest Server** e criará o serviço `rest_server` em `/usr/local/etc/rc.d/`.

---

## **▶️ Uso do serviço**

- **Iniciar o serviço:**

```shell
service rest_server start
```

- **Parar o serviço:**

```shell
service rest_server stop
```

- **Verificar status:**

```shell
service rest_server status
```

---

## **📂 Estrutura de armazenamento**

- Diretório dos backups:

```
/mnt/backups/rest-server
```

- Dataset ZFS utilizado: `zroot/rest-server`
- Comandos usados para criar e montar o dataset:

```
zfs create zroot/rest-server
zfs set mountpoint=/mnt/backups/rest-server zroot/rest-server
```

---

## **🔗 Referências**

- Projeto **Rest Server**: <https://github.com/restic/rest-server>
- Ferramenta **Restic**: <https://restic.net>
- Repositório adaptado para FreeBSD: <https://github.com/pmbatatais/backup-server.git>

---

✍️ Criado com dedicação e ZFS por **Leonardo Ribeiro**  
💡 Agora você tem um servidor de backup pronto para receber seus dados de forma segura e confiável!
