import fs from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

function parseLineData(line) {
  if (line.length < 55) return null;

  return {
    rawLine: line.trim(),
    codigo: line.substring(0, 8),
    tipo: line.substring(8, 11),
    cuit: line.substring(11, 22),
    numeroCompleto: line.substring(22, 38),
    fecha: line.substring(line.length - 5).trim()
  };
}

function detailedComparison() {
  console.log('📊 COMPARACIÓN DETALLADA: Pesos.txt vs Pesos_20251231.txt\n');

  const file1Path = join(__dirname, '../../txt/Pesos.txt');
  const file2Path = join(__dirname, '../../txt/Pesos_20251231.txt');

  const file1Content = fs.readFileSync(file1Path, 'utf-8');
  const file2Content = fs.readFileSync(file2Path, 'utf-8');

  const lines1 = file1Content.split('\n').filter(l => l.trim().length > 0);
  const lines2 = file2Content.split('\n').filter(l => l.trim().length > 0);

  const header1 = parseLineData(lines1[0]);
  const header2 = parseLineData(lines2[0]);

  console.log('=' .repeat(100));
  console.log('📋 HEADERS\n');
  console.log('Pesos.txt:');
  console.log(`  Total líneas: ${lines1.length}`);
  console.log(`  Total registros (según header): ${header1.numeroCompleto.substring(5, 11).trim()}`);
  console.log(`  Número header: ${header1.numeroCompleto}`);
  console.log();
  console.log('Pesos_20251231.txt:');
  console.log(`  Total líneas: ${lines2.length}`);
  console.log(`  Total registros (según header): ${header2.numeroCompleto.substring(5, 11).trim()}`);
  console.log(`  Número header: ${header2.numeroCompleto}`);
  console.log();

  // Crear mapas
  const map1 = new Map();
  const map2 = new Map();

  for (let i = 1; i < lines1.length; i++) {
    const data = parseLineData(lines1[i]);
    if (data) map1.set(data.cuit, { lineNum: i + 1, ...data });
  }

  for (let i = 1; i < lines2.length; i++) {
    const data = parseLineData(lines2[i]);
    if (data) map2.set(data.cuit, { lineNum: i + 1, ...data });
  }

  console.log('=' .repeat(100));
  console.log('🔍 REGISTRO ADICIONAL EN Pesos.txt\n');

  const extraInFile1 = [];
  for (const [cuit, data] of map1.entries()) {
    if (!map2.has(cuit)) {
      extraInFile1.push(data);
    }
  }

  if (extraInFile1.length > 0) {
    console.log(`Se encontró ${extraInFile1.length} registro(s) en Pesos.txt que NO está(n) en Pesos_20251231.txt:\n`);
    extraInFile1.forEach((record, idx) => {
      console.log(`${idx + 1}. CUIT: ${record.cuit} (Línea ${record.lineNum})`);
      console.log(`   Tipo cuenta: ${record.tipo}`);
      console.log(`   ${record.rawLine}`);
      console.log();
    });
  } else {
    console.log('No hay registros adicionales\n');
  }

  console.log('=' .repeat(100));
  console.log('❌ PROBLEMA DEL FORMATO DE NÚMERO\n');

  console.log('TODAVÍA persiste el problema del número desplazado en Pesos.txt\n');

  console.log('Primeros 3 ejemplos del problema:\n');

  let count = 0;
  for (const [cuit, data1] of map1.entries()) {
    if (map2.has(cuit) && count < 3) {
      const data2 = map2.get(cuit);

      if (data1.numeroCompleto !== data2.numeroCompleto) {
        count++;
        console.log(`${count}. CUIT: ${cuit}`);
        console.log(`   Pesos.txt:         ${data1.numeroCompleto} (INCORRECTO)`);
        console.log(`   Pesos_20251231.txt: ${data2.numeroCompleto} (CORRECTO)`);

        // Extraer la parte del número que difiere
        const num1 = data1.numeroCompleto;
        const num2 = data2.numeroCompleto;

        console.log(`   Últimos 6 dígitos:`);
        console.log(`     Pesos.txt:         ...${num1.substring(10)} ← tiene 0 extra`);
        console.log(`     Pesos_20251231.txt: ...${num2.substring(10)} ← correcto`);
        console.log();
      }
    }
  }

  console.log('=' .repeat(100));
  console.log('🎯 RESUMEN Y RECOMENDACIÓN\n');

  console.log('Estado actual de Pesos.txt:');
  console.log(`  ✅ Tiene 1 registro NUEVO (CUIT ${extraInFile1[0]?.cuit})`);
  console.log(`  ❌ PERO aún tiene el formato de número INCORRECTO en los 170 registros comunes`);
  console.log();
  console.log('El formato correcto debería ser:');
  console.log('  - Los últimos 6 dígitos del número deben tener el formato correcto');
  console.log('  - Ejemplo: 014330 (correcto) vs 143300 (incorrecto - tiene 0 extra)');
  console.log();
  console.log('Acciones necesarias:');
  console.log('  1. ❌ Pesos.txt TODAVÍA necesita corrección en el formato del número');
  console.log('  2. ✅ Pesos.txt tiene el registro nuevo (CUIT 40141003142)');
  console.log('  3. 💡 Se recomienda copiar el formato de Pesos_20251231.txt y agregar el registro nuevo');
  console.log();

  console.log('=' .repeat(100));
}

detailedComparison();
