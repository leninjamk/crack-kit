#!/bin/bash
# config.sh - EDITA uma vez so, depois nao mexe mais.
#
# 1) Cria repo privado no GitHub: https://github.com/new  (marca Private)
# 2) Gera token em: https://github.com/settings/tokens
#    - Generate new token (classic)
#    - Marca so "repo"
#    - Copia (ghp_...)
# 3) Preenche as variaveis abaixo

GITHUB_USER="SEU_USUARIO_AQUI"
GITHUB_REPO="crack-kit"
GITHUB_TOKEN="ghp_COLA_SEU_TOKEN_AQUI"

# Nome que aparece nos commits (qualquer coisa)
GIT_NAME="crack-vm"
GIT_EMAIL="crack@vm.local"
