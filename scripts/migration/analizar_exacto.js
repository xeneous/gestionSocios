const linea1 = "0668128125239373502805180000000014330001999010000325000012/25";
const linea2 = "0668128125239373502805180000000001433001999010000325000012/25";

console.log('Análisis exacto según el código Dart:\n');
console.log('Pesos.txt:          ' + linea1);
console.log('Pesos_20251231.txt: ' + linea2);
console.log('');

// Código Dart usa posiciones basadas en 1, JavaScript en 0
// Dart pos 1-9 = JS 0-8
// Dart pos 10-25 = JS 9-24
// Dart pos 26-37 = JS 25-36
// Dart pos 38-45 = JS 37-44
// Dart pos 46-56 = JS 45-55

console.log('Campo por campo (según código Dart):');
console.log('');
console.log('1-9 (Código detalle): ');
console.log('  Pesos.txt:          ' + linea1.substring(0, 9));
console.log('  Pesos_20251231.txt: ' + linea2.substring(0, 9));
console.log('');

console.log('10-25 (Tarjeta - 16 dígitos):');
console.log('  Pesos.txt:          ' + linea1.substring(9, 25));
console.log('  Pesos_20251231.txt: ' + linea2.substring(9, 25));
console.log('');

console.log('26-37 (Socio ID - 12 dígitos):');
const socioId1 = linea1.substring(25, 37);
const socioId2 = linea2.substring(25, 37);
console.log('  Pesos.txt:          ' + socioId1);
console.log('  Pesos_20251231.txt: ' + socioId2);
console.log('  ¿Iguales?: ' + (socioId1 === socioId2 ? 'SÍ' : 'NO'));
console.log('');

console.log('38-45 (Constante - 8 dígitos):');
console.log('  Pesos.txt:          ' + linea1.substring(37, 45));
console.log('  Pesos_20251231.txt: ' + linea2.substring(37, 45));
console.log('');

console.log('46-56 (Importe - 11 dígitos):');
const importe1 = linea1.substring(45, 56);
const importe2 = linea2.substring(45, 56);
console.log('  Pesos.txt:          ' + importe1);
console.log('  Pesos_20251231.txt: ' + importe2);
console.log('  ¿Iguales?: ' + (importe1 === importe2 ? 'SÍ' : 'NO'));
console.log('');

console.log('57-61 (Fecha):');
console.log('  Pesos.txt:          ' + linea1.substring(56, 61));
console.log('  Pesos_20251231.txt: ' + linea2.substring(56, 61));
console.log('');

console.log('='.repeat(80));
console.log('CONCLUSIÓN:');
console.log('='.repeat(80));
console.log('El importe está CORRECTO en ambos archivos: ' + importe1);
console.log('El problema está en el campo SOCIO_ID:');
console.log('  Correcto (Pesos.txt):          ' + socioId1);
console.log('  Incorrecto (Pesos_20251231.txt): ' + socioId2);
console.log('');
console.log('El socio_id se genera con 12 dígitos usando formatNumeroConPadding');
console.log('Pero el formato tiene un error en la generación.');
