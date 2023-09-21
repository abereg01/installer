dfc=$HOME/dotfiles/.config;
cfg=$HOME/.config/;
lcl=$HOME/.local/;

mkdir -pv $HOME/.ssh;
mkdir -pv $HOME/.local/share/fonts;

ln -sf $dfc/fish/ $cfg/fish/
ln -sf $dfc/rofi/ $cfg/rofi/
ln -sf $dfc/sxhkd/ $cfg/sxhkd/
ln -sf $dfc/zathura/ $cfg/zathura/

