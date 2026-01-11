import fs from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

function parseLineData(line) {
  if (line.length < 55) return null;

  return {
    rawLine: line,
    codigo: line.substring(0, 8),
    tipo: line.substring(8, 11),
    cuit: line.substring(11, 22),
    // El número parece estar en la posición 22-38 (16 chars)
    numeroCompleto: line.substring(22, 38),
    resto: line.substring(38)
  };
}

function analyzeNumberDifferences() {
  console.log('🔍 Análisis detallado de diferencias en números\n');

  const file1Path = join(__dirname, '../../txt/Pesos.txt');
  const file2Path = join(__dirname, '../../txt/Pesos_20251231.txt');

  const file1Content = fs.readFileSync(file1Path, 'utf-8');
  const file2Content = fs.readFileSync(file2Path, 'utf-8');

  const lines1 = file1Content.split('\n').filter(l => l.trim().length > 0);
  const lines2 = file2Content.split('\n').filter(l => l.trim().length > 0);

  // Analizar primer registro como ejemplo
  console.log('=' .repeat(100));
  console.log('📋 EJEMPLO: Análisis detallado del primer registro diferente\n');

  const example1 = parseLineData(lines1[1]); // Línea 2 (skip header)
  const example2 = parseLineData(lines2[28]); // Línea 29 donde está el mismo CUIT en archivo 2

  console.log('CUIT: 39373502805\n');
  console.log('11/25:');
  console.log(`  Línea completa: ${example1.rawLine}`);
  console.log(`  Número completo: ${example1.numeroCompleto}`);
  console.log();

  console.log('12/25:');
  console.log(`  Línea completa: ${example2.rawLine}`);
  console.log(`  Número completo: ${example2.numeroCompleto}`);
  console.log();

  // Comparar carácter por carácter
  console.log('Comparación carácter por carácter del número:');
  console.log('Posición | 11/25 | 12/25 | ¿Igual?');
  console.log('-'.repeat(40));

  for (let i = 0; i < example1.numeroCompleto.length; i++) {
    const char1 = example1.numeroCompleto[i];
    const char2 = example2.numeroCompleto[i];
    const igual = char1 === char2 ? '✓' : '✗';
    console.log(`   ${i.toString().padStart(2)}    |   ${char1}   |   ${char2}   |   ${igual}`);
  }

  console.log();
  console.log('Observación:');
  console.log(`  11/25: 0000000${example1.numeroCompleto.substring(7)} → "${example1.numeroCompleto.substring(7, 12)}" (posiciones 7-11)`);
  console.log(`  12/25: 0000000${example2.numeroCompleto.substring(7)} → "${example2.numeroCompleto.substring(7, 12)}" (posiciones 7-11)`);
  console.log();

  // Análisis de todos los registros
  console.log('=' .repeat(100));
  console.log('📊 ANÁLISIS DE TODOS LOS REGISTROS\n');

  const map1 = new Map();
  const map2 = new Map();

  // Procesar archivo 1 (skip header)
  for (let i = 1; i < lines1.length; i++) {
    const data = parseLineData(lines1[i]);
    if (data) {
      map1.set(data.cuit, data);
    }
  }

  // Procesar archivo 2 (skip header)
  for (let i = 1; i < lines2.length; i++) {
    const data = parseLineData(lines2[i]);
    if (data) {
      map2.set(data.cuit, data);
    }
  }

  const issues = [];

  for (const [cuit, data1] of map1.entries()) {
    if (map2.has(cuit)) {
      const data2 = map2.get(cuit);

      // Comparar números
      const num1 = data1.numeroCompleto;
      const num2 = data2.numeroCompleto;

      if (num1 !== num2) {
        // Extraer el número sin los ceros iniciales
        const value1 = parseInt(num1, 10);
        const value2 = parseInt(num2, 10);

        issues.push({
          cuit,
          num1,
          num2,
          value1,
          value2,
          diff: value1 - value2,
          ratio: value1 / value2
        });
      }
    }
  }

  console.log(`Total de registros con diferencias en número: ${issues.length}\n`);

  // Analizar el patrón
  const ratios = issues.map(i => i.ratio);
  const avgRatio = ratios.reduce((a, b) => a + b, 0) / ratios.length;

  console.log('Análisis del patrón:');
  console.log(`  Ratio promedio (11/25 ÷ 12/25): ${avgRatio.toFixed(4)}`);
  console.log();

  // Verificar si todos tienen un patrón similar
  const allSimilarRatio = ratios.every(r => Math.abs(r - 10) < 0.1);

  if (allSimilarRatio) {
    console.log('✅ PATRÓN DETECTADO: Todos los números en 11/25 tienen un "0" extra (están multiplicados por 10)');
  } else {
    console.log('⚠️  No se detectó un patrón uniforme en las diferencias');
  }

  console.log();
  console.log('Primeros 10 ejemplos de diferencias:');
  console.log('-'.repeat(100));
  console.log('CUIT        | Valor 11/25 | Valor 12/25 | Diferencia | Ratio');
  console.log('-'.repeat(100));

  issues.slice(0, 10).forEach(issue => {
    console.log(
      `${issue.cuit} | ${issue.value1.toString().padStart(11)} | ${issue.value2.toString().padStart(11)} | ${issue.diff.toString().padStart(10)} | ${issue.ratio.toFixed(2)}`
    );
  });

  console.log();
  console.log('=' .repeat(100));
  console.log('🎯 CONCLUSIÓN:\n');

  if (allSimilarRatio && avgRatio >= 9.9 && avgRatio <= 10.1) {
    console.log('✅ El archivo Pesos_20251231.txt (12/25) es CORRECTO');
    console.log('❌ El archivo Pesos.txt (11/25) tiene un ERROR: los números tienen un "0" extra al final');
    console.log();
    console.log('Ejemplo:');
    console.log('  11/25 (INCORRECTO): 0000000014330 → 14330 (con 0 extra)');
    console.log('  12/25 (CORRECTO):   0000000001433 → 1433 (correcto)');
  } else {
    console.log('⚠️  Las diferencias no siguen un patrón claro de multiplicación por 10');
  }

  console.log();
  console.log('🆕 Registros nuevos en 12/25:');
  for (const [cuit, data] of map2.entries()) {
    if (!map1.has(cuit)) {
      console.log(`  - CUIT: ${cuit}`);
      console.log(`    Número: ${data.numeroCompleto} → ${parseInt(data.numeroCompleto, 10)}`);
    }
  }

  console.log('=' .repeat(100));
}

// Ejecutar análisis
analyzeNumberDifferences();
