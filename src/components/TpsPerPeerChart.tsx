import React from 'react';
import { Line } from 'react-chartjs-2';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
} from 'chart.js';

ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend
);

interface Transaction {
  id: string;
  from: string;
  to: string;
  amount: number;
  block: number;
  timestamp: string; // Format attendu : "DD/MM/YYYY, HH:mm:ss"
}

interface TpsPerPeerChartProps {
  transactions?: Transaction[];
}

const TpsPerPeerChart: React.FC<TpsPerPeerChartProps> = ({ transactions = [] }) => {
  // Si pas de transactions, afficher un placeholder
  if (transactions.length === 0) {
    return (
      <div className="h-full flex items-center justify-center text-gray-400">
        Pas de données de transactions disponibles pour le chart TPS
      </div>
    );
  }

  // Parser les timestamps et grouper par heure
  const timeBuckets = new Map<string, { count: number; totalAmount: number }>();

  transactions.forEach((tx) => {
    try {
      let date: Date;
      const dateStr = (tx.timestamp || '').trim();

      // Tenter de parser le format "DD/MM/YYYY, HH:mm:ss"
      const frMatch = dateStr.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4}),?\s+(\d{1,2}):(\d{2}):?(\d{2})?$/);
      if (frMatch) {
        const [, day, month, year, hour, minute, second] = frMatch;
        date = new Date(+year, +month - 1, +day, +hour, +minute, +(second || 0));
      } else {
        // Sinon tenter ISO ou tout autre format natif
        date = new Date(dateStr);
      }

      if (isNaN(date.getTime())) return; // timestamp invalide, on skip

      // Clé par heure : YYYY-MM-DD HH:00
      const bucketKey = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')} ${String(date.getHours()).padStart(2, '0')}:00`;

      if (!timeBuckets.has(bucketKey)) {
        timeBuckets.set(bucketKey, { count: 0, totalAmount: 0 });
      }

      const bucket = timeBuckets.get(bucketKey)!;
      bucket.count += 1;
      bucket.totalAmount += tx.amount;
    } catch {
      // timestamp imparsable, on ignore cette tx
    }
  });

  // Trier les buckets par date croissante
  const sortedBuckets = Array.from(timeBuckets.entries()).sort((a, b) => a[0].localeCompare(b[0]));

  // Préparer les labels et datasets
  const labels = sortedBuckets.map(([key]) => key); // Ex. : "2025-06-08 20:00"

  const tpsData = sortedBuckets.map(([_, bucket]) => {
    // TPS = nombre de tx / 3600 secondes (pour heure)
    return parseFloat((bucket.count / 3600).toFixed(2)); // Convertir en nombre
  });

  const volumeData = sortedBuckets.map(([_, bucket]) => bucket.totalAmount);

  const data = {
    labels,
    datasets: [
      {
        label: 'TPS (Transactions par seconde)',
        data: tpsData,
        borderColor: '#14CB84',
        backgroundColor: 'rgba(20, 203, 132, 0.1)',
        tension: 0.4,
        yAxisID: 'y1',
      },
      {
        label: 'Volume Transactions',
        data: volumeData,
        borderColor: '#970d0d',
        backgroundColor: 'rgba(151, 13, 13, 0.1)',
        tension: 0.4,
        yAxisID: 'y2',
      },
    ],
  };

  const options = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: {
        position: 'top' as const,
        labels: {
          color: '#fff',
        },
      },
      title: {
        display: true,
        text: 'Transactions Per Second & Volume',
        color: '#fff',
      },
    },
    scales: {
      x: {
        grid: {
          color: 'rgba(255, 255, 255, 0.1)',
        },
        ticks: {
          color: '#fff',
        },
      },
      y1: {
        type: 'linear' as const,
        position: 'left' as const,
        grid: {
          color: 'rgba(255, 255, 255, 0.1)',
        },
        ticks: {
          color: '#14CB84',
        },
        title: {
          display: true,
          text: 'TPS',
          color: '#14CB84',
        },
      },
      y2: {
        type: 'linear' as const,
        position: 'right' as const,
        grid: {
          drawOnChartArea: false, // Évite les lignes croisées
        },
        ticks: {
          color: '#970d0d',
        },
        title: {
          display: true,
          text: 'Volume',
          color: '#970d0d',
        },
      },
    },
  };

  return (
    <div className="h-full">
      <Line data={data} options={options} />
    </div>
  );
};

export default TpsPerPeerChart;