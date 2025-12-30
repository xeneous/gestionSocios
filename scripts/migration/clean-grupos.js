import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config();

const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY
);

const { error } = await supabase.from('grupos_agrupados').delete().neq('id', 0);
if (error) console.error('Error:', error);
else console.log('✅ grupos_agrupados limpiada');
