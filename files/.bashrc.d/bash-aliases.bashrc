# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

alias ports='sudo nmap -sT -O localhost'

checkcert() {
  cat /dev/null | openssl s_client -showcerts -connect $1:443  -servername $1 2>&1
}

checkcertdate() {
  cat /dev/null | openssl s_client  -connect $1:443  -servername $1 2>/dev/null | openssl x509 -noout -dates
}
chktlsdate() {
  echo | openssl s_client -servername $1 -connect $1:443 | openssl x509 -noout -dates
}

# kubernetes set namespace
kns() {
    namespace=$1
    kubectl config set-context --current --namespace=$1
}
