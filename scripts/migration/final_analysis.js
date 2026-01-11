import fs from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

function parseLineData(line) {
  if (line.length < 55) return null;

  // Estructura del formato según lo observado:
  // Posiciones 0-7: Código banco (06681281)
  // Posiciones 8-10: Tipo (125, 130, 131, etc)
  // Posiciones 11-21: CUIT (11 dígitos)
  // Posiciones 22-37: Número/Monto compuesto (16 dígitos)
  //   - Los primeros caracteres parecen ser código
  //   - Los últimos caracteres son el monto

  return {
    rawLine: line.trim(),
    codigo: line.substring(0, 8),
    tipo: line.substring(8, 11),
    cuit: line.substring(11, 22),
    numeroCompleto: line.substring(22, 38),
    fecha: line.substring(line.length - 5).trim() // Últimos 5 caracteres
  };
}

function finalAnalysis() {
  console.log('🎯 Análisis Final de Diferencias entre archivos Pesos\n');

  const file1Path = join(__dirname, '../../txt/Pesos.txt');
  const file2Path = join(__dirname, '../../txt/Pesos_20251231.txt');

  const file1Content = fs.readFileSync(file1Path, 'utf-8');
  const file2Content = fs.readFileSync(file2Path, 'utf-8');

  const lines1 = file1Content.split('\n').filter(l => l.trim().length > 0);
  const lines2 = file2Content.split('\n').filter(l => l.trim().length > 0);

  console.log('=' .repeat(100));
  console.log('📊 RESUMEN DE ARCHIVOS\n');
  console.log(`Pesos.txt (11/25): ${lines1.length} líneas`);
  console.log(`Pesos_20251231.txt (12/25): ${lines2.length} líneas`);
  console.log(`Diferencia: +${lines2.length - lines1.length} líneas\n`);

  // Analizar headers
  const header1 = parseLineData(lines1[0]);
  const header2 = parseLineData(lines2[0]);

  console.log('=' .repeat(100));
  console.log('📋 HEADERS (Primera línea)\n');
  console.log(`11/25: ${header1.rawLine}`);
  console.log(`       Tipo: ${header1.tipo} | Total registros: 170 | Número: ${header1.numeroCompleto}`);
  console.log();
  console.log(`12/25: ${header2.rawLine}`);
  console.log(`       Tipo: ${header2.tipo} | Total registros: 172 | Número: ${header2.numeroCompleto}`);
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

  // Encontrar nuevos registros
  const newRecords = [];
  for (const [cuit, data] of map2.entries()) {
    if (!map1.has(cuit)) {
      newRecords.push(data);
    }
  }

  console.log('=' .repeat(100));
  console.log('🆕 REGISTROS NUEVOS EN 12/25\n');
  if (newRecords.length === 0) {
    console.log('No hay registros nuevos\n');
  } else {
    console.log(`Total: ${newRecords.length} registros nuevos\n`);
    newRecords.forEach((record, idx) => {
      console.log(`${idx + 1}. CUIT: ${record.cuit} (Línea ${record.lineNum})`);
      console.log(`   ${record.rawLine}`);
      console.log();
    });
  }

  // Analizar diferencias en registros comunes
  console.log('=' .repeat(100));
  console.log('🔍 ANÁLISIS DE DIFERENCIAS EN REGISTROS EXISTENTES\n');

  const samples = [];
  let count = 0;

  for (const [cuit, data1] of map1.entries()) {
    if (map2.has(cuit)) {
      const data2 = map2.get(cuit);

      // Comparar todo excepto la fecha
      const line1WithoutDate = data1.rawLine.substring(0, data1.rawLine.length - 5);
      const line2WithoutDate = data2.rawLine.substring(0, data2.rawLine.length - 5);

      if (line1WithoutDate !== line2WithoutDate) {
        count++;
        if (samples.length < 5) {
          samples.push({ cuit, data1, data2 });
        }
      }
    }
  }

  console.log(`Total de registros con diferencias: ${count}\n`);

  if (samples.length > 0) {
    console.log('Primeros 5 ejemplos:\n');
    samples.forEach((sample, idx) => {
      console.log(`${idx + 1}. CUIT: ${sample.cuit}`);
      console.log(`   11/25 (línea ${sample.data1.lineNum}): ${sample.data1.rawLine}`);
      console.log(`   12/25 (línea ${sample.data2.lineNum}): ${sample.data2.rawLine}`);

      // Resaltar la diferencia en el número
      const num1 = sample.data1.numeroCompleto;
      const num2 = sample.data2.numeroCompleto;

      console.log(`   Número 11/25: ${num1}`);
      console.log(`   Número 12/25: ${num2}`);

      // Encontrar dónde difieren
      let diffStart = -1;
      for (let i = 0; i < num1.length; i++) {
        if (num1[i] !== num2[i]) {
          diffStart = i;
          break;
        }
      }

      if (diffStart >= 0) {
        console.log(`   Diferencia desde posición ${diffStart}:`);
        console.log(`     11/25: ...${num1.substring(diffStart)}`);
        console.log(`     12/25: ...${num2.substring(diffStart)}`);
      }

      console.log();
    });
  }

  // Verificar si todos los registros están presentes
  console.log('=' .repeat(100));
  console.log('✅ VERIFICACIÓN DE INTEGRIDAD\n');

  const missing = [];
  for (const [cuit] of map1.entries()) {
    if (!map2.has(cuit)) {
      missing.push(cuit);
    }
  }

  if (missing.length === 0) {
    console.log('✅ Todos los registros de 11/25 están presentes en 12/25');
  } else {
    console.log(`❌ Faltan ${missing.length} registros de 11/25 en 12/25:`);
    missing.forEach(cuit => console.log(`   - CUIT: ${cuit}`));
  }

  console.log();
  console.log(`✅ Registros comunes: ${map1.size - missing.length}`);
  console.log(`🆕 Registros nuevos en 12/25: ${newRecords.length}`);
  console.log(`❌ Registros eliminados de 11/25: ${missing.length}`);

  console.log();
  console.log('=' .repeat(100));
  console.log('🎯 CONCLUSIÓN FINAL\n');
  console.log(`El archivo Pesos_20251231.txt (12/25) tiene:`);
  console.log(`  • ${newRecords.length} registros nuevos`);
  console.log(`  • ${count} registros con diferencias en el número/monto`);
  console.log(`  • ${map1.size - missing.length - count} registros idénticos (excepto fecha)`);
  console.log();

  if (count === map1.size) {
    console.log('⚠️  TODOS los registros comunes tienen diferencias en el número.');
    console.log('   Esto sugiere un cambio en el formato o corrección sistemática.');
  } else if (count > 0) {
    console.log(`⚠️  ${count} de ${map1.size} registros tienen diferencias.`);
  } else {
    console.log('✅ No hay diferencias significativas entre los archivos (solo fecha).');
  }

  console.log('=' .repeat(100));
}

finalAnalysis();
