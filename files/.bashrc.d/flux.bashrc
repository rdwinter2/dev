export GITHUB_TOKEN=$(cat ~/.logins/gh)
export GITLAB_TOKEN_NAME=flux
export GITLAB_TOKEN=$(cat ~/.logins/gl)
export GITHUB_USER=rdwinter2
export GITLAB_USER=rdwinter2
export LAB_CORE_HOST=https://gitlab.com
export LAB_CORE_TOKEN=$(cat ~/.logins/gl)
export LAB_CORE_USER=rdwinter2
. <(flux completion bash)
source <(lab completion)
