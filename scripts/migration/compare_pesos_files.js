import fs from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

function parseLineData(line) {
  // Formato esperado de las líneas
  // Posiciones aproximadas basadas en los datos:
  // 0-7: Código (06681281)
  // 8-10: Tipo (131 o 125)
  // 11-21: CUIT/CUIL (11 dígitos)
  // 22-37: Número (16 dígitos, incluye monto)
  // 38-54: Fecha y otros campos

  if (line.length < 55) return null;

  return {
    rawLine: line,
    codigo: line.substring(0, 8),
    tipo: line.substring(8, 11),
    cuit: line.substring(11, 22),
    numero: line.substring(22, 38),
    resto: line.substring(38)
  };
}

function comparePesosFiles() {
  console.log('📊 Comparando archivos Pesos.txt y Pesos_20251231.txt\n');

  const file1Path = join(__dirname, '../../txt/Pesos.txt');
  const file2Path = join(__dirname, '../../txt/Pesos_20251231.txt');

  const file1Content = fs.readFileSync(file1Path, 'utf-8');
  const file2Content = fs.readFileSync(file2Path, 'utf-8');

  const lines1 = file1Content.split('\n').filter(l => l.trim().length > 0);
  const lines2 = file2Content.split('\n').filter(l => l.trim().length > 0);

  console.log(`📄 Pesos.txt: ${lines1.length} líneas`);
  console.log(`📄 Pesos_20251231.txt: ${lines2.length} líneas`);
  console.log(`📊 Diferencia: ${lines2.length - lines1.length} líneas\n`);

  // Analizar primera línea (header)
  console.log('=' .repeat(100));
  console.log('🔍 COMPARACIÓN DE HEADERS (Primera línea)\n');

  const header1 = parseLineData(lines1[0]);
  const header2 = parseLineData(lines2[0]);

  console.log('Pesos.txt (11/25):');
  console.log(`  Línea completa: ${lines1[0]}`);
  console.log(`  Código: ${header1.codigo}`);
  console.log(`  Tipo: ${header1.tipo}`);
  console.log(`  Número: ${header1.numero}`);
  console.log();

  console.log('Pesos_20251231.txt (12/25):');
  console.log(`  Línea completa: ${lines2[0]}`);
  console.log(`  Código: ${header2.codigo}`);
  console.log(`  Tipo: ${header2.tipo}`);
  console.log(`  Número: ${header2.numero}`);
  console.log();

  // Crear mapas por CUIT para comparar
  const map1 = new Map();
  const map2 = new Map();

  // Procesar archivo 1 (skip header)
  for (let i = 1; i < lines1.length; i++) {
    const data = parseLineData(lines1[i]);
    if (data) {
      const key = data.cuit;
      map1.set(key, { line: i + 1, data, rawLine: lines1[i] });
    }
  }

  // Procesar archivo 2 (skip header)
  for (let i = 1; i < lines2.length; i++) {
    const data = parseLineData(lines2[i]);
    if (data) {
      const key = data.cuit;
      map2.set(key, { line: i + 1, data, rawLine: lines2[i] });
    }
  }

  console.log('=' .repeat(100));
  console.log('🔍 ANÁLISIS DE REGISTROS\n');
  console.log(`Registros únicos en Pesos.txt: ${map1.size}`);
  console.log(`Registros únicos en Pesos_20251231.txt: ${map2.size}\n`);

  // Buscar registros solo en archivo 1
  const onlyIn1 = [];
  for (const [cuit, record] of map1.entries()) {
    if (!map2.has(cuit)) {
      onlyIn1.push(record);
    }
  }

  // Buscar registros solo en archivo 2
  const onlyIn2 = [];
  for (const [cuit, record] of map2.entries()) {
    if (!map1.has(cuit)) {
      onlyIn2.push(record);
    }
  }

  // Buscar registros que están en ambos
  const inBoth = [];
  const differences = [];

  for (const [cuit, record1] of map1.entries()) {
    if (map2.has(cuit)) {
      const record2 = map2.get(cuit);
      inBoth.push({ cuit, record1, record2 });

      // Comparar si hay diferencias
      if (record1.rawLine !== record2.rawLine) {
        differences.push({ cuit, record1, record2 });
      }
    }
  }

  console.log('=' .repeat(100));
  console.log(`✅ Registros en AMBOS archivos: ${inBoth.length}`);
  console.log(`⚠️  Registros SOLO en Pesos.txt (11/25): ${onlyIn1.length}`);
  console.log(`🆕 Registros SOLO en Pesos_20251231.txt (12/25): ${onlyIn2.length}`);
  console.log(`🔄 Registros con DIFERENCIAS: ${differences.length}\n`);

  if (onlyIn1.length > 0) {
    console.log('=' .repeat(100));
    console.log('⚠️  REGISTROS SOLO EN Pesos.txt (11/25):\n');
    onlyIn1.forEach((record, idx) => {
      console.log(`${idx + 1}. Línea ${record.line} - CUIT: ${record.data.cuit}`);
      console.log(`   ${record.rawLine}`);
    });
    console.log();
  }

  if (onlyIn2.length > 0) {
    console.log('=' .repeat(100));
    console.log('🆕 REGISTROS SOLO EN Pesos_20251231.txt (12/25):\n');
    onlyIn2.forEach((record, idx) => {
      console.log(`${idx + 1}. Línea ${record.line} - CUIT: ${record.data.cuit}`);
      console.log(`   ${record.rawLine}`);
    });
    console.log();
  }

  if (differences.length > 0) {
    console.log('=' .repeat(100));
    console.log('🔄 REGISTROS CON DIFERENCIAS:\n');
    differences.slice(0, 10).forEach((diff, idx) => {
      console.log(`${idx + 1}. CUIT: ${diff.cuit}`);
      console.log(`   Pesos.txt (línea ${diff.record1.line}):`);
      console.log(`   ${diff.record1.rawLine}`);
      console.log(`   Pesos_20251231.txt (línea ${diff.record2.line}):`);
      console.log(`   ${diff.record2.rawLine}`);
      console.log();
    });

    if (differences.length > 10) {
      console.log(`   ... y ${differences.length - 10} diferencias más\n`);
    }
  }

  // Verificar si todos los registros están correctos (mismo CUIT en ambos)
  let allCorrect = true;
  const issues = [];

  for (const { cuit, record1, record2 } of inBoth) {
    if (record1.rawLine !== record2.rawLine) {
      // Verificar si solo difiere en la fecha al final
      const line1WithoutDate = record1.rawLine.substring(0, record1.rawLine.length - 5);
      const line2WithoutDate = record2.rawLine.substring(0, record2.rawLine.length - 5);

      if (line1WithoutDate !== line2WithoutDate) {
        allCorrect = false;
        issues.push({ cuit, record1, record2 });
      }
    }
  }

  console.log('=' .repeat(100));
  console.log('🎯 VERIFICACIÓN DE INTEGRIDAD:\n');

  if (issues.length === 0) {
    console.log('✅ Todos los registros comunes son idénticos (excepto fecha)\n');
  } else {
    console.log(`❌ Encontrados ${issues.length} registros con diferencias más allá de la fecha:\n`);
    issues.slice(0, 5).forEach((issue, idx) => {
      console.log(`${idx + 1}. CUIT: ${issue.cuit}`);
      console.log(`   11/25: ${issue.record1.rawLine}`);
      console.log(`   12/25: ${issue.record2.rawLine}`);
      console.log();
    });
  }

  console.log('=' .repeat(100));
  console.log('📊 RESUMEN FINAL:\n');
  console.log(`Total Pesos.txt (11/25): ${lines1.length} líneas (${map1.size} registros)`);
  console.log(`Total Pesos_20251231.txt (12/25): ${lines2.length} líneas (${map2.size} registros)`);
  console.log(`Registros nuevos en 12/25: ${onlyIn2.length}`);
  console.log(`Registros eliminados en 12/25: ${onlyIn1.length}`);
  console.log(`Diferencia neta: ${onlyIn2.length - onlyIn1.length} registros`);
  console.log('=' .repeat(100));
}

// Ejecutar comparación
comparePesosFiles();
