const linea1 = "0668128125239373502805180000000014330001999010000325000012/25";
const linea2 = "0668128125239373502805180000000001433001999010000325000012/25";

console.log('Comparación detallada de las líneas:\n');
console.log('Pesos.txt:         ' + linea1);
console.log('Pesos_20251231.txt: ' + linea2);
console.log('');

// Encontrar diferencias
let diff = '';
for (let i = 0; i < Math.max(linea1.length, linea2.length); i++) {
  if (linea1[i] !== linea2[i]) {
    diff += '^';
  } else {
    diff += ' ';
  }
}

console.log('Diferencias:        ' + diff);
console.log('');

// Desglosar campos
console.log('Desglose de campos:');
console.log('Posición  | Pesos.txt | Pesos_20251231 | Campo');
console.log('----------|-----------|----------------|------');
console.log('1-8       | ' + linea1.substring(0, 8) + '  | ' + linea2.substring(0, 8) + '       | Código banco');
console.log('9-11      | ' + linea1.substring(8, 11) + '       | ' + linea2.substring(8, 11) + '            | Tipo');
console.log('12-22     | ' + linea1.substring(11, 22) + ' | ' + linea2.substring(11, 22) + '    | CUIT');
console.log('23-38     | ' + linea1.substring(22, 38) + '| ' + linea2.substring(22, 38) + '   | Número/Referencia');
console.log('39-56     | ' + linea1.substring(38, 56) + ' | ' + linea2.substring(38, 56) + '  | Constante + Importe');
console.log('57-61     | ' + linea1.substring(56, 61) + '     | ' + linea2.substring(56, 61) + '      | Fecha MM/YY');
console.log('');

console.log('Analizando campo 23-38 (Número/Referencia):');
const campo1 = linea1.substring(22, 38);
const campo2 = linea2.substring(22, 38);
console.log('Pesos.txt:          ' + campo1);
console.log('Pesos_20251231.txt: ' + campo2);
console.log('');

console.log('Analizando campo 39-56:');
const campo_importe1 = linea1.substring(38, 56);
const campo_importe2 = linea2.substring(38, 56);
console.log('Pesos.txt:          ' + campo_importe1);
console.log('Pesos_20251231.txt: ' + campo_importe2);
console.log('');

// El campo 39-56 debería ser: constante (8) + importe (11)
console.log('Separando constante e importe (39-56):');
console.log('Constante (39-46):');
console.log('  Pesos.txt:          ' + campo_importe1.substring(0, 8));
console.log('  Pesos_20251231.txt: ' + campo_importe2.substring(0, 8));
console.log('Importe (47-56):');
console.log('  Pesos.txt:          ' + campo_importe1.substring(8, 18));
console.log('  Pesos_20251231.txt: ' + campo_importe2.substring(8, 18));
