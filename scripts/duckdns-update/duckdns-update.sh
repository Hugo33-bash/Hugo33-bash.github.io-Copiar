#!/bin/bash
echo "url=https://www.duckdns.org/update?domains=minextcloud2,minextcloud2-docx01&token=TU_TOKEN_NUEVO_AQUI&ip=" \
  | curl -k -o ~/duckdns.log -K -
