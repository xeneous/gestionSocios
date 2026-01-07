/// Configuración de constantes para archivos de presentación de tarjetas
class PresentacionConfig {
  // Constantes VISA
  static const String visaEstablecimiento = '00050008428997';
  static const String visaCodigo = '029999';
  static const int visaMaxItemsLote = 99;
  static const int visaLongitudLinea = 80;
  
  // Constantes MASTERCARD  
  static const String mastercardHeader = '066812811';
  static const String mastercardDetalle = '066812812';
  static const String mastercardConstante = '00199901';
  static const int mastercardLongitudLinea = 129;
  
  // IDs de tarjetas (ajustar según tu BD)
  static const int visaTarjetaId = 1;
  
  PresentacionConfig._();
}
