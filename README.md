# RokuCaster

Canal Roku nativo em BrightScript e SceneGraph. O app recebe URLs ou playlists pela rede local usando o External Control Protocol (ECP) da Roku e reproduz a mídia com o nó `Video`.

## O que já funciona

- Tela de espera em português para deixar o canal aberto na TV.
- Recebimento de vídeo ao abrir o canal com um deep link ECP.
- Recebimento de novos vídeos com o canal aberto usando `roInputEvent`.
- Reprodução sequencial de playlists recebidas como JSON pelo ECP.
- Busca de um manifesto JSON hospedado pelo app Android na rede local.
- Reprodução de links HTTP e HTTPS nos formatos HLS (`.m3u8`), MP4 (`.mp4`, `.m4v`), MPEG-DASH (`.mpd`) e Smooth Streaming (`.ism/manifest`).
- Controle de reprodução pelo controle remoto Roku e retorno à tela receptora ao terminar ou ocorrer um erro.

Cada URL precisa apontar para uma mídia que o Roku consiga acessar diretamente. Este primeiro receptor não retransmite a tela do celular nem converte formatos.

## Instalar na TV

1. Ative o modo de desenvolvedor na Roku TV e anote o endereço IP e a senha de instalação exibidos pela TV.
2. Gere o pacote com `./scripts/package.sh`.
3. No computador conectado à mesma rede, abra `http://<IP-DA-TV>` e entre com o usuário `rokudev` e a senha de desenvolvedor.
4. Envie `build/roku-caster.zip` pela página **Development Application Installer**.
5. Quando o canal abrir, deixe o RokuCaster na tela para receber vídeos.

## Protocolo para o futuro app de celular

O celular e a TV devem estar na mesma rede local, com o controle por apps móveis habilitado nas configurações Roku. O celular pode descobrir o dispositivo por SSDP e enviar comandos ECP para a porta `8060`.

### Abrir o canal e iniciar um link curto

Deep links Roku aceitam `contentId` de até 255 caracteres. Para um endereço curto, o app do celular pode iniciar a reprodução junto com a abertura do canal:

```sh
curl -d '' 'http://<IP-DA-TV>:8060/launch/dev?contentId=https%3A%2F%2Fcdn.example.com%2Fvideo.m3u8&mediaType=shortFormVideo'
```

O canal trata o `contentId` como URL da mídia.

### Abrir o canal e enviar um link longo ou outro vídeo

Para links longos, abra o canal primeiro e depois envie o evento `input`. O endpoint ECP aceita parâmetros extras; o canal os recebe por `roInput` sem a limitação do `contentId` do deep link:

```sh
curl -d '' 'http://<IP-DA-TV>:8060/launch/dev'
curl -d '' 'http://<IP-DA-TV>:8060/input?url=https%3A%2F%2Fcdn.example.com%2Fvideo.m3u8&title=Meu%20video&streamFormat=hls'
```

Parâmetros aceitos em `/input`:

- `url` (obrigatório): endereço HTTP ou HTTPS acessível pela TV.
- `title` (opcional): título exibido nos controles de reprodução.
- `streamFormat` (opcional): `hls`, `mp4`, `dash` ou `ism`; quando omitido, é inferido pela extensão do endereço e assume HLS se não houver extensão reconhecida.
- `action=stop` (opcional): encerra a reprodução atual.

Codifique cada valor de query string como URL encoding. Em produção, o app de celular deve trocar `dev` pelo ID do canal se a Roku exigir um ID de canal publicado; para instalação local, use `dev`.

### Enviar uma playlist hospedada na rede local

Para evitar colocar todos os endereços de vídeo dentro de uma única URL ECP, envie o endereço HTTP de um manifesto JSON. A Roku baixa o manifesto com um nó `Task` e reproduz os itens pela ordem recebida.

```sh
curl -d '' 'http://192.168.1.20:8060/input?playlistUrl=http%3A%2F%2F192.168.1.50%3A8080%2Fplaylist%2Fabc123.json'
```

No exemplo, troque os endereços e a porta pelos valores reais do RokuCaster Android.

O manifesto é um array JSON no mesmo formato abaixo. Cada endereço de vídeo precisa ser acessível pela TV:

Cada item precisa ter `url`; `title` e `streamFormat` são opcionais. A Roku reproduz os itens em sequência e retorna à tela receptora quando o último terminar.

```js
const playlist = [
  {
    url: "https://cdn.example.com/video-1.m3u8",
    title: "Vídeo 1",
    streamFormat: "hls",
  },
  {
    url: "https://cdn.example.com/video-2.mp4",
    title: "Vídeo 2",
    streamFormat: "mp4",
  },
];

// Hospede este array em um endereço HTTP alcançável pela Roku e envie o endereço:
await fetch(`http://${rokuIp}:8060/input?playlistUrl=${encodeURIComponent(manifestUrl)}`, {
  method: "POST",
  body: "",
});
```

O parâmetro `playlist` com JSON inline também continua aceito para listas pequenas.

O app também aceita um único vídeo pelos parâmetros `url` ou `contentId`. Enviar um novo comando substitui a reprodução atual.

## Estrutura

```text
manifest                 Configuração e deep linking do canal
source/main.brs          Inicialização SceneGraph e entrada ECP
components/MainScene.xml Interface de espera e nó Video
components/MainScene.brs Estado do receptor e reprodução
components/PlaylistTask.xml  Tarefa para baixar manifestos de playlist
components/PlaylistTask.brs  Leitura HTTP do manifesto na Roku
scripts/package.sh       Geração do ZIP para sideload
```
