set -euo pipefail
exec kitty \
  --class=com.mitchellh.kitty.NetworkConnections \
  --title="Network Connections" \
  env \
    NEWT_COLORS="root=white,default:border=yellow,default:window=white,default:shadow=default,default:title=yellow,default:button=white,gray:actbutton=yellow,gray:compactbutton=white,default:checkbox=white,default:actcheckbox=yellow,gray:entry=white,gray:actentry=yellow,gray:label=white,default:listbox=white,default:actlistbox=yellow,gray:sellistbox=white,gray:actsellistbox=yellow,gray:textbox=white,default:acttextbox=yellow,gray:helpline=gray,default:roottext=gray,default" \
    NMT_NEWT_COLORS="plainLabel=white,default:badLabel=red,default:disabledButton=gray,default:textboxWithBackground=white,gray" \
    nmtui
