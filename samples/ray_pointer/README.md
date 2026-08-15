# 遠隔ポインタ

レイで離れた対象を指して選ぶサンプルです。手を対象に近づけると、レイが引っ込みます。

## 見どころ

- **近接と遠隔の切り替え**。手が対象から25cm以内に入ると、レイを消して近くのものを選ぶ扱いに変えます。MRTK3のInteraction Mode Managerに相当する部分の最小版です。両方が同時に効くと、意図しない方が反応します
- **レイの出所を1箇所で決める**。コントローラーがあればaim pose、無ければ視線を使います。視線のときはビームを描かず、カーソルだけ出します。目の前に線が立つと視界が潰れるためです
- 決定はコントローラーの`select`アクション、Hand Trackingではpinch。pinchは掴む閾値と離す閾値をずらしています
- 対象の`Area3D`は**専用の物理レイヤー（16）**に置いています。ランチャーのUI（レイヤー8）とレイが混ざらないようにするためです

## 必要な設定

- `openxr_action_map.tres`の`select`アクション（simple controllerは`select/click`、その他は`trigger/value`）

## 対応端末

Quest 3 / PICO 4 Ultra / VIVE Focus Vision / Android XR

## 単体で動かす

`samples/ray_pointer/sample.tscn`をエディタで開いてF6。
