import 'package:firebase_app/gen/assets.gen.dart';

List<String> banners = [
  Assets.images.banner1.path,
  Assets.images.banner2.path,
  Assets.images.banner3.path,
];

List<String> topBrands = [
  'All',
  'Porsche',
  'Maserati',
  'BMW',
  'Mercedes',
  'Tesla',
  'Honda',
  'Toyota',
  'Audi',
  'Hyundai',
  'Kia',
];

List<String> theTitleOfTheListOfCars = [
  'Popular cars',
  'New cars',
  'Economy cars',
  'Expensive cars',
];

List<List<Map<String, String>>> carsPerCategory = [
  // Popular cars
  [
    {
      'brand': 'Maserati',
      'name': 'Granturismo',
      'image': Assets.images.maseratiGranturismo.path,
      'price': '1349.00',
    },
    {
      'brand': 'Porsche',
      'name': '911 GTS RS',
      'image': Assets.images.porsche911GTSRS.path,
      'price': '999.00',
    },
    {
      'brand': 'Audi',
      'name': 'A4',
      'image': Assets.images.audiA4.path,
      'price': '1099.00',
    },
    {
      'brand': 'Audi',
      'name': 'A6',
      'image': Assets.images.audiA6.path,
      'price': '1199.00',
    },
    {
      'brand': 'Mercedes Benz',
      'name': 'G',
      'image': Assets.images.mercedesG.path,
      'price': '2000.00',
    },
    {
      'brand': 'Mercedes Benz',
      'name': 'E Class',
      'image': Assets.images.mercedesBenzEClass.path,
      'price': '2100.00',
    },
    {
      'brand': 'Mercedes Benz',
      'name': 'GLC',
      'image': Assets.images.mercedesBenzGlc.path,
      'price': '2090.00',
    },
    {
      'brand': 'Mercedes Benz',
      'name': 'GLS',
      'image': Assets.images.mercedesBenzGls.path,
      'price': '2190.00',
    },
    {
      'brand': 'Mercedes Benz',
      'name': 'S Class',
      'image': Assets.images.mercedesBenzSClass.path,
      'price': '2050.00',
    },
    {
      'brand': 'Mercedes Benz',
      'name': 'A Class',
      'image': Assets.images.mercedesBenzAClass.path,
      'price': '2450.00',
    },
  ],
  // New cars
  [
    {
      'brand': 'BMW',
      'name': 'M3 2024',
      'image': Assets.images.bmwM3.path,
      'price': '1099.00',
    },
    {
      'brand': 'Porsche',
      'name': 'Panamera',
      'image': Assets.images.porschePanamera.path,
      'price': '1299.00',
    },
    {
      'brand': 'Tesla',
      'name': 'Model Y',
      'image': Assets.images.teslaModelY.path,
      'price': '1499.00',
    },
    {
      'brand': 'Audi',
      'name': 'Q5',
      'image': Assets.images.audiQ5.path,
      'price': '1350.00',
    },
    {
      'brand': 'BMW',
      'name': '3(G20)',
      'image': Assets.images.bmw3G20.path,
      'price': '1200.00',
    },
    {
      'brand': 'BMW',
      'name': '5(G30)',
      'image': Assets.images.bmw5G30.path,
      'price': '1350.00',
    },
    {
      'brand': 'Hyundai',
      'name': 'Elentra',
      'image': Assets.images.hyundaiElantra.path,
      'price': '1090.00',
    },
    {
      'brand': 'Hyundai',
      'name': 'Palisade',
      'image': Assets.images.hyundaiPalisade.path,
      'price': '1050.00',
    },
    {
      'brand': 'Kia',
      'name': 'Sportage',
      'image': Assets.images.kiaSportage.path,
      'price': '1100.00',
    },
    {
      'brand': 'Kia',
      'name': 'Stringer',
      'image': Assets.images.kiaStinger.path,
      'price': '1199.00',
    },
    {
      'brand': 'Toyota',
      'name': 'Camry',
      'image': Assets.images.toyotaCamry.path,
      'price': '2000.00',
    },
  ],
  // Economy cars
  [
    {
      'brand': 'Toyota',
      'name': 'Yaris',
      'image': Assets.images.toyotaYaris.path,
      'price': '899.00',
    },
    {
      'brand': 'Honda',
      'name': 'Civic',
      'image': Assets.images.hondaCivic.path,
      'price': '699.00',
    },
    {
      'brand': 'Audi',
      'name': 'A3',
      'image': Assets.images.audiA3.path,
      'price': '799.00',
    },
    {
      'brand': 'Audi',
      'name': 'A4',
      'image': Assets.images.audiA4.path,
      'price': '1099.00',
    },
    {
      'brand': 'Audi',
      'name': 'A6',
      'image': Assets.images.audiA6.path,
      'price': '1199.00',
    },
    {
      'brand': 'Audi',
      'name': 'A8',
      'image': Assets.images.audiA8.path,
      'price': '1299.00',
    },
    {
      'brand': 'Audi',
      'name': 'Q3',
      'image': Assets.images.audiQ3Black.path,
      'price': '1090.00',
    },
    {
      'brand': 'BMW',
      'name': 'X3 (G01)',
      'image': Assets.images.bmwX3G01.path,
      'price': '1199.00',
    },
    {
      'brand': 'Honda',
      'name': 'Accord',
      'image': Assets.images.hondaAccord.path,
      'price': '600.00',
    },
    {
      'brand': 'Honda',
      'name': 'CR-V',
      'image': Assets.images.hondaCrV.path,
      'price': '700.00',
    },
    {
      'brand': 'Honda',
      'name': 'HR-V',
      'image': Assets.images.hondaHrV.path,
      'price': '850.00',
    },
    {
      'brand': 'Honda',
      'name': 'Jazz',
      'image': Assets.images.hondaJazz.path,
      'price': '750.00',
    },
    {
      'brand': 'Honda',
      'name': 'Pilot',
      'image': Assets.images.hondaPilot.path,
      'price': '999.00',
    },
    {
      'brand': 'Hyundai',
      'name': 'Santa Fe',
      'image': Assets.images.hyundaiSantaFe.path,
      'price': '1199.00',
    },
    {
      'brand': 'Kia',
      'name': 'Soul',
      'image': Assets.images.kiaSoul.path,
      'price': '450.00',
    },
    {
      'brand': 'Kia',
      'name': 'Niro',
      'image': Assets.images.kiaNiro.path,
      'price': '550.00',
    },
    {
      'brand': 'Kia',
      'name': 'Seltos',
      'image': Assets.images.kiaSeltos.path,
      'price': '750.00',
    },
    {
      'brand': 'Toyota',
      'name': 'Corolla',
      'image': Assets.images.toyotaCorolla.path,
      'price': '820.00',
    },
    {
      'brand': 'Toyota',
      'name': 'Hilux',
      'image': Assets.images.toyotaHilux.path,
      'price': '790.00',
    },
    {
      'brand': 'Toyota',
      'name': 'RAV4',
      'image': Assets.images.toyotaRav4.path,
      'price': '850.00',
    },
  ],
  // Expensive cars
  [
    {
      'brand': 'Tesla',
      'name': 'Model Y',
      'image': Assets.images.teslaModelY.path,
      'price': '1499.00',
    },
    {
      'brand': 'Tesla',
      'name': 'Model S',
      'image': Assets.images.teslaModelS.path,
      'price': '1099.00',
    },
    {
      'brand': 'Tesla',
      'name': 'Model X',
      'image': Assets.images.teslaModelX.path,
      'price': '1049.00',
    },
    {
      'brand': 'Tesla',
      'name': 'Model S Plaid',
      'image': Assets.images.teslaModelSPlaid.path,
      'price': '1199.00',
    },
    {
      'brand': 'Audi',
      'name': 'R8',
      'image': Assets.images.audiR8.path,
      'price': '2900.00',
    },
    {
      'brand': 'BMW',
      'name': 'I8',
      'image': Assets.images.bmwI8.path,
      'price': '3050.00',
    },
    {
      'brand': 'BMW',
      'name': 'I7 G70',
      'image': Assets.images.bmwI7.path,
      'price': '4450.00',
    },
    {
      'brand': 'Hyundai',
      'name': ' Kona Electric',
      'image': Assets.images.hyundaiKonaElectricFront.path,
      'price': '2050.00',
    },
    {
      'brand': 'Maserati',
      'name': 'Alfieri',
      'image': Assets.images.maseratiAlfieri.path,
      'price': '7500.00',
    },
    {
      'brand': 'Maserati',
      'name': 'Grecale',
      'image': Assets.images.maseratiGrecale.path,
      'price': '5500.00',
    },
    {
      'brand': 'Maserati',
      'name': 'Ghibli',
      'image': Assets.images.maseratiGhibli.path,
      'price': '6500.00',
    },
    {
      'brand': 'Maserati',
      'name': 'Levante',
      'image': Assets.images.maseratiLevante.path,
      'price': '5500.00',
    },
    {
      'brand': 'Maserati',
      'name': 'MC20',
      'image': Assets.images.maseratiMc20.path,
      'price': '7500.00',
    },
    {
      'brand': 'Porsche',
      'name': 'Carrera GT',
      'image': Assets.images.porscheCarreraGt.path,
      'price': '3600.00',
    },
    {
      'brand': 'Porsche',
      'name': 'Macan',
      'image': Assets.images.porscheMacan.path,
      'price': '4590.00',
    },
  ],
];
