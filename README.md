# gyazo-uploader

iOSの写真全部Gyazoに上げるアプリです。
配布はしてないのでXCodeでビルドしてください。
iOS 15.2.1 にて動作を確認しています。

## スクリーンショット

[![Image from Gyazo](https://i.gyazo.com/cb959a414a83658a63314d25f5b78cce.png)](https://gyazo.com/cb959a414a83658a63314d25f5b78cce)

## 使い方

https://gyazo.com/api にてアプリを登録し、自分用のアクセストークンを入手してください。
Info.plistの`GYAZO_ACCESS_TOKEN`にアクセストークンをセットしてください。

[![Image from Gyazo](https://i.gyazo.com/d86f2ce20b366916fdaf436e254187a7.png)](https://gyazo.com/d86f2ce20b366916fdaf436e254187a7)

ビルドして起動してください。

アプリが起動すると写真へのアクセス許可が求められるので、全ての写真を許可してください。

> 1000 photos will upload

のように表示されたら、「Upload!」をクリックするとアップロードが始まります。
アプリが開いている間しかアップロードされないので、しばらくお待ちください…。

アップロードが完了すると、Completeという表示になります。
「Reload」を押すと再度新しい画像を読み込みます。
※同じ画像は２回アップロードしないようになっています。
