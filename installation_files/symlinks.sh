dfc=$HOME/dotfiles/.config;
#dfl=$HOME/dotfiles/.local;
cfg=$HOME/.config/;
lcl=$HOME/.local/;
dff=$HOME/.dotfiles/.local/share/fonts/;
dfi=$HOME/.dotfiles/images/;

mkdir -pv $HOME/scripts;
mkdir -pv $HOME/images;
mkdir -pv $HOME/.ssh;
mkdir -pv $HOME/.local/share/fonts;

ln -sf $dfc/fish/ $cfg/fish/
ln -sf $dfc/rofi/ $cfg/rofi/
ln -sf $dfc/sxhkd/ $cfg/sxhkd/
ln -sf $dfc/zathura/ $cfg/zathura/
ln -sf $dfc/scripts/ $HOME/scripts/
ln -sf $dff/Hack/ $lcl/share/fonts/
ln -sf $dff/Iosevka/ $lcl/share/fonts/
ln -sf $dff/'Jetbrains Mono'/ $lcl/share/fonts/
ln -fs $dfi/wallpapers/ $HOME/images/
