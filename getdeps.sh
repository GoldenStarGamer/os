if ! command -v apt &>/dev/null; then
  echo "Error: 'apt' package manager not found on this Linux distribution. This script only supports distros with apt."
  echo "You will have to download the dependencies manually."
  exit 1
fi

sudo apt update
sudo xargs apt install < DEPENDENCIES.txt
