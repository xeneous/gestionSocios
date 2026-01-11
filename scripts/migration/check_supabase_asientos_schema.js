import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

dotenv.config({ path: join(__dirname, '.env') });

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function checkSchema() {
  console.log('🔍 Consultando esquema de asientos_header...\n');

  // Obtener un registro de ejemplo
  const { data, error } = await supabase
    .from('asientos_header')
    .select('*')
    .limit(1);

  if (error) {
    console.error('❌ Error:', error);
  } else if (data && data.length > 0) {
    console.log('📋 Columnas de asientos_header:');
    Object.keys(data[0]).forEach(col => {
      console.log(`   - ${col}: ${typeof data[0][col]}`);
    });
  } else {
    console.log('⚠️  Tabla vacía, no se pueden determinar columnas');
  }

  console.log('\n🔍 Consultando esquema de asientos_items...\n');

  const { data: itemsData, error: itemsError } = await supabase
    .from('asientos_items')
    .select('*')
    .limit(1);

  if (itemsError) {
    console.error('❌ Error:', itemsError);
  } else if (itemsData && itemsData.length > 0) {
    console.log('📋 Columnas de asientos_items:');
    Object.keys(itemsData[0]).forEach(col => {
      console.log(`   - ${col}: ${typeof itemsData[0][col]}`);
    });
  } else {
    console.log('⚠️  Tabla vacía, no se pueden determinar columnas');
  }
}

checkSchema();
