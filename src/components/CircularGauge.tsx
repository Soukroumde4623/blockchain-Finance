import React from "react";

export default function CircularGauge({ percent }: { percent: number }) {
  // Semi-cercle : dasharray/offset pour 75%
  const radius = 100;
  const circ = Math.PI * radius;
  const pct = percent / 100;
  const fill = circ * pct;

  return (
    <div className="relative flex flex-col items-center justify-center h-44 w-full">
      <svg width="220" height="110" viewBox="0 0 220 110">
        {/* Trail */}
        <path
          d="M20,110 A90,90 0 0,1 200,110"
          stroke="#2E335A"
          strokeWidth="13"
          fill="none"
        />
        {/* Actual value */}
        <path
          d="M20,110 A90,90 0 0,1 200,110"
          stroke="#7A85FF"
          strokeWidth="13"
          fill="none"
          strokeDasharray={circ}
          strokeDashoffset={circ - fill}
          strokeLinecap="round"
        />
      </svg>
      <div className="absolute top-16 left-1/2 -translate-x-1/2 flex flex-col items-center">
        <span className="text-white text-[2.7rem] font-extrabold">{percent}%</span>
        <span className="bg-[#183D2F] text-[#14CB84] text-sm px-3 py-[2px] rounded-full font-bold mt-1">+10%</span>
      </div>
    </div>
  );
}
