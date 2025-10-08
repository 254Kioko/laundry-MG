-- Create enum types
CREATE TYPE payment_status AS ENUM ('full', 'deposit', 'unpaid');
CREATE TYPE payment_mode AS ENUM ('cash', 'mpesa', 'none');
CREATE TYPE order_status AS ENUM ('pending', 'completed', 'overdue');

-- Create customers table
CREATE TABLE customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  phone TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create clothing_types table (for pricing management)
CREATE TABLE clothing_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  price DECIMAL(10,2) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create orders table
CREATE TABLE orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  receipt_number TEXT NOT NULL UNIQUE,
  date_received DATE NOT NULL DEFAULT CURRENT_DATE,
  collection_date DATE NOT NULL,
  total_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
  amount_paid DECIMAL(10,2) NOT NULL DEFAULT 0,
  payment_status payment_status NOT NULL DEFAULT 'unpaid',
  payment_mode payment_mode NOT NULL DEFAULT 'none',
  status order_status NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create clothes table
CREATE TABLE clothes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  color TEXT NOT NULL,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  price_per_item DECIMAL(10,2) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create storage_fees table
CREATE TABLE storage_fees (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  amount DECIMAL(10,2) NOT NULL,
  date_added DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create profiles table for attendants
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT,
  role TEXT DEFAULT 'attendant',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE clothing_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE clothes ENABLE ROW LEVEL SECURITY;
ALTER TABLE storage_fees ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- RLS Policies for customers
CREATE POLICY "Authenticated users can view customers"
  ON customers FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can insert customers"
  ON customers FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Authenticated users can update customers"
  ON customers FOR UPDATE
  TO authenticated
  USING (true);

-- RLS Policies for clothing_types
CREATE POLICY "Authenticated users can view clothing types"
  ON clothing_types FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can manage clothing types"
  ON clothing_types FOR ALL
  TO authenticated
  USING (true);

-- RLS Policies for orders
CREATE POLICY "Authenticated users can view orders"
  ON orders FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can insert orders"
  ON orders FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Authenticated users can update orders"
  ON orders FOR UPDATE
  TO authenticated
  USING (true);

-- RLS Policies for clothes
CREATE POLICY "Authenticated users can view clothes"
  ON clothes FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can insert clothes"
  ON clothes FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- RLS Policies for storage_fees
CREATE POLICY "Authenticated users can view storage fees"
  ON storage_fees FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can insert storage fees"
  ON storage_fees FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- RLS Policies for profiles
CREATE POLICY "Users can view their own profile"
  ON profiles FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
  ON profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updated_at
CREATE TRIGGER update_customers_updated_at
  BEFORE UPDATE ON customers
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_clothing_types_updated_at
  BEFORE UPDATE ON clothing_types
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_orders_updated_at
  BEFORE UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Create function to handle new user signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name)
  VALUES (NEW.id, NEW.raw_user_meta_data->>'full_name');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Trigger to create profile on signup
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

-- Insert default clothing types
INSERT INTO clothing_types (name, price) VALUES
  ('Shirt', 100.00),
  ('Trouser', 150.00),
  ('Dress', 200.00),
  ('Bedsheet', 250.00),
  ('Blanket', 300.00),
  ('Jacket', 180.00),
  ('Skirt', 120.00);

-- Create function to generate receipt number
CREATE OR REPLACE FUNCTION generate_receipt_number()
RETURNS TEXT AS $$
DECLARE
  new_number TEXT;
  counter INTEGER;
BEGIN
  SELECT COUNT(*) + 1 INTO counter FROM orders;
  new_number := 'RCP-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(counter::TEXT, 4, '0');
  RETURN new_number;
END;
$$ LANGUAGE plpgsql;