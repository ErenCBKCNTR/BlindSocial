import 'package:flutter/material.dart';

/// Görme engelli kullanıcılar için özel olarak tasarlanmış, ekran okuyucular
/// (TalkBack/VoiceOver) tarafından sadece TEK BİR KEZ ve İSTENDİĞİ GİBİ okunan
/// evrensel IconButton (veya dairesel buton) bileşeni.
///
/// Flutter'daki [IconButton] veya [ElevatedButton] kendi içlerinde her zaman
/// bir "button" semantics nodu yaratır ve dıştan tekrar [Semantics] ile sarmalandığında
/// "Mikrofon Ayarları" -> "Etiketsiz Düğme" gibi arka arkaya çift okumalara sebep olur.
///
/// Bu widget, içerisindeki tüm standart Semantics'leri [ExcludeSemantics] ile temizler
/// ve dışarıya sadece kullanıcının belirlediği tek bir birleştirilmiş [Semantics] nodu sunar.
class AccessibleIconButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget icon;
  final String label;
  final String? hint;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final EdgeInsetsGeometry? padding;
  final double iconSize;

  const AccessibleIconButton({
    Key? key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.hint,
    this.backgroundColor,
    this.foregroundColor,
    this.padding = const EdgeInsets.all(16.0),
    this.iconSize = 28.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      hint: hint,
      button: true,
      enabled: onPressed != null,
      child: ExcludeSemantics(
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor ?? Colors.grey[800],
            foregroundColor: foregroundColor ?? Colors.white,
            padding: padding,
            shape: const CircleBorder(),
          ),
          child: icon,
        ),
      ),
    );
  }
}
