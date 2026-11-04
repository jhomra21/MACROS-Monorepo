import { describe, expect, it } from 'bun:test'
import { normalizeOpenFoodFactsFood, normalizeUSDAFood } from '../src/normalizedFood'

const usda = (name: string, brand?: string) => normalizeUSDAFood({
  id: 'usda:1',
  name,
  brand,
  servingDescription: '100 g',
  sourceName: 'USDA FoodData Central',
  sourceURL: 'https://fdc.nal.usda.gov/food-details/1',
  caloriesPerServing: 59.92000000000001,
  proteinPerServing: 10.024000000000001,
  sodiumPerServing: 12.345,
})

describe('v2 search presentation boundary', () => {
  it('rounds USDA nutrition after serving scaling, without float noise', () => {
    expect(usda('Yogurt').nutrition).toEqual({ calories: 60, protein: 10, sodium: 12.3 })
    expect(normalizeUSDAFood({
      id: 'usda:2', name: 'Yogurt', servingDescription: '50 g', gramsPerServing: 50,
      sourceName: 'USDA', sourceURL: 'https://example.com',
      caloriesPerServing: 119.84000000000002, proteinPerServing: 20.048000000000002,
    }).nutrition).toEqual({ calories: 60, protein: 10 })
  })

  it('rounds OFF nutrition after grams/mg conversion and serving scaling', () => {
    expect(normalizeOpenFoodFactsFood({
      product_name: 'Yogurt', serving_quantity: 50, serving_quantity_unit: 'g',
      nutriments: {
        'energy-kcal_100g': 119.84000000000002, proteins_100g: 20.048000000000002,
        sodium_100g: 0.02469, cholesterol_100g: 0.01269,
      },
    })?.nutrition).toEqual({ calories: 60, protein: 10, sodium: 12.3, cholesterol: 6.3 })
  })

  it('display-cases all-capital names and brands for both sources', () => {
    expect(usda('GREEK YOGURT', 'CHOBANI').name).toBe('Greek Yogurt')
    expect(usda('GREEK YOGURT', 'CHOBANI').brand).toBe('Chobani')
    const off = normalizeOpenFoodFactsFood({ product_name: 'GREEK YOGURT', brands: 'CHOBANI' })
    expect(off?.name).toBe('Greek Yogurt')
    expect(off?.brand).toBe('Chobani')
  })

  it('preserves strings containing lowercase letters', () => {
    expect(usda('Greek YOGURT', 'iÖGO').name).toBe('Greek YOGURT')
    expect(usda('Greek YOGURT', 'iÖGO').brand).toBe('iÖGO')
  })

  it('strips only trailing legal brand suffixes and collapses whitespace', () => {
    for (const suffix of [', Inc.', ' Inc.', ' LLC', ' Corp.', ' Corporation', ' Co.', ' Company', ' Limited', ' Ltd.']) {
      expect(usda('Yogurt', `  Chobani  ${suffix}  `).brand).toBe('Chobani')
      expect(usda('Yogurt', `CHOBANI${suffix.toUpperCase()}`).brand).toBe('Chobani')
    }

    expect(usda('  GREEK   YOGURT  ', '  THE   DAIRY  ').name).toBe('Greek Yogurt')
    expect(usda('Yogurt', '  THE   DAIRY  ').brand).toBe('The Dairy')
    expect(usda('Yogurt', 'Company Kitchen').brand).toBe('Company Kitchen')
    expect(usda('Yogurt', 'INCREDIBLE').brand).toBe('Incredible')
  })

  it('keeps tokens with digits verbatim', () => {
    expect(usda('2% MILK WITH B12').name).toBe('2% Milk with B12')
    expect(usda('Milk', '3M FOODS').brand).toBe('3M Foods')
  })

  it('lowercases interior connectors, not the first word', () => {
    expect(usda('CREAM OF CHICKEN WITH RICE AND HERBS').name)
      .toBe('Cream of Chicken with Rice and Herbs')
    expect(usda('WITH RICE').name).toBe('With Rice')
  })

  it('preserves only explicit brand acronyms, not every short uppercase word', () => {
    expect(usda('LOW FAT GREEK YOGURT', 'M&S USA FOODS').name).toBe('Low Fat Greek Yogurt')
    expect(usda('Yogurt', 'M&S USA FOODS').brand).toBe('M&S USA Foods')
    expect(usda('Yogurt', 'THE BIG COW').brand).toBe('The Big Cow')
  })

  it('omits missing and whitespace-only brands without inventing one', () => {
    for (const brand of [undefined, '', '   ']) {
      expect(usda('Yogurt', brand).brand).toBeUndefined()
      expect(normalizeOpenFoodFactsFood({ product_name: 'Yogurt', brands: brand })?.brand)
        .toBeUndefined()
    }
  })
})
