# Gravador de Tela (Delphi + FFmpeg)

Aplicativo leve e funcional para gravação contínua da tela do Windows. Desenvolvido em **Delphi** com uso do **FFmpeg**, o programa permite gravar qualquer monitor do sistema com divisão automática de vídeos, limpeza programada e execução na bandeja do sistema.

---

## 📦 Requisitos

- **Windows 10 ou superior**
- [`ffmpeg.exe`](https://www.gyan.dev/ffmpeg/builds/) (versão estática)

> ⚠️ Coloque o `ffmpeg.exe` **na mesma pasta do executável `GravadorDeTela.exe`**.

### Onde baixar o FFmpeg?

Baixe aqui:  
🔗 https://www.gyan.dev/ffmpeg/builds/

Escolha a opção:  
**"Release full build"**  
Extraia o `ffmpeg.exe` da pasta `bin` e coloque ao lado do `.exe` do aplicativo.

---

## 🚀 Como usar

1. Execute `GravadorDeTela.exe`
2. Configure:
   - **Diretório onde os vídeos serão salvos**
   - **Tempo de duração de cada vídeo**
   - **Monitor a ser gravado**
   - **Por quanto tempo os vídeos devem ser mantidos**
   - **Com que frequência o aplicativo verifica e apaga vídeos antigos**
3. Clique em **Iniciar Gravação**

O programa grava em segundo plano e salva os vídeos automaticamente no local escolhido.

---

## 🛠 Funcionalidades

✅ Gravação da tela de qualquer monitor  
✅ Vídeos segmentados por tempo  
✅ Limpeza automática de vídeos antigos  
✅ Ícone na bandeja do sistema  
✅ Ícone dinâmico (parado ou gravando)  
✅ Opção de iniciar minimizado  
✅ Opção de iniciar já gravando  
✅ Salva configurações entre execuções  
✅ Interface simples e intuitiva

---

## 🖥️ Iniciar com o Windows

1. Pressione `Win + R` e digite: shell:startup
2. Cole um **atalho** do `GravadorDeTela.exe` dentro dessa pasta.
3. No aplicativo, marque a opção **"Iniciar aplicativo minimizado e gravando"**.

Com isso, o programa iniciará com o Windows e já começará a gravar automaticamente.

---

## 📄 Licença

Uso livre para fins pessoais e acadêmicos. Para usos comerciais, entre em contato com o autor.

---

## 👤 Autor

Desenvolvido por [Thalik Bussacro](https://github.com/thalikbussacro) com Delphi 12.
