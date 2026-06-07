# assets

`social-preview.svg` — imagem de marca (1280×640) para o **Social Preview** do GitHub (a imagem que aparece quando o repo é compartilhado no X/LinkedIn/Slack/Discord).

## Como definir no GitHub
O GitHub aceita **PNG/JPG/GIF** (não SVG) no social preview. Converta e faça upload:

1. Gere o PNG a partir do SVG (qualquer uma):
   - Abra `social-preview.svg` no navegador → screenshot 1280×640; ou
   - Use um conversor (ex.: `rsvg-convert -w 1280 -h 640 social-preview.svg -o social-preview.png`, ou Inkscape, ou um conversor SVG→PNG online).
2. No GitHub: **Settings → General → Social preview → Upload an image** e selecione o PNG.

> Dica: também serve como banner no topo do README, se quiser.
