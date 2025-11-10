import type { Metadata } from 'next'
import { Inter } from 'next/font/google'
import './globals.css'

const inter = Inter({ subsets: ['latin'] })

export const metadata: Metadata = {
  title: 'Credit Card Deals Tracker',
  description: 'Track the best credit card welcome offers and bonuses',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body className={inter.className}>
        <header className="bg-blue-600 text-white">
          <div className="container mx-auto px-4 py-6">
            <h1 className="text-3xl font-bold">Credit Card Deals Tracker</h1>
            <p className="text-blue-100">Find the best credit card welcome offers</p>
          </div>
        </header>
        <main className="container mx-auto px-4 py-8">
          {children}
        </main>
        <footer className="bg-gray-100 mt-12">
          <div className="container mx-auto px-4 py-6 text-center text-gray-600">
            <p>&copy; 2025 Credit Card Deals Tracker. All rights reserved.</p>
          </div>
        </footer>
      </body>
    </html>
  )
}
