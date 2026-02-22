import React, { useState } from "react";

export default function UserAddressCard() {
  const [isOpen, setIsOpen] = useState(false);
  const [formData, setFormData] = useState({
    country: "United States",
    cityState: "Phoenix, Arizona, United States",
    postalCode: "ERT 2489",
    taxId: "AS4568384"
  });

  const openModal = () => setIsOpen(true);
  const closeModal = () => setIsOpen(false);

  const handleSave = () => {
    // Handle save logic here
    console.log("Saving changes...", formData);
    closeModal();
  };

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: value
    }));
  };

  return (
    <>
      <div className="p-5 border border-gray-200 rounded-2xl bg-gray-900 text-white">
        <div className="flex flex-col gap-6">
          <div>
            <h4 className="text-lg font-semibold mb-6">Address</h4>

            <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
              <div>
                <p className="mb-2 text-sm text-gray-400">Country</p>
                <p className="text-base font-medium">{formData.country}</p>
              </div>

              <div>
                <p className="mb-2 text-sm text-gray-400">City/State</p>
                <p className="text-base font-medium">{formData.cityState}</p>
              </div>

              <div>
                <p className="mb-2 text-sm text-gray-400">Postal Code</p>
                <p className="text-base font-medium">{formData.postalCode}</p>
              </div>

              <div>
                <p className="mb-2 text-sm text-gray-400">TAX ID</p>
                <p className="text-base font-medium">{formData.taxId}</p>
              </div>
            </div>
          </div>

          <button
            onClick={openModal}
            className="flex items-center justify-center gap-2 rounded-lg border border-gray-600 bg-gray-800 px-4 py-3 text-sm font-medium hover:bg-gray-700 transition"
          >
            <svg
              className="fill-current"
              width="18"
              height="18"
              viewBox="0 0 18 18"
              fill="none"
              xmlns="http://www.w3.org/2000/svg"
            >
              <path
                fillRule="evenodd"
                clipRule="evenodd"
                d="M15.0911 2.78206C14.2125 1.90338 12.7878 1.90338 11.9092 2.78206L4.57524 10.116C4.26682 10.4244 4.0547 10.8158 3.96468 11.2426L3.31231 14.3352C3.25997 14.5833 3.33653 14.841 3.51583 15.0203C3.69512 15.1996 3.95286 15.2761 4.20096 15.2238L7.29355 14.5714C7.72031 14.4814 8.11172 14.2693 8.42013 13.9609L15.7541 6.62695C16.6327 5.74827 16.6327 4.32365 15.7541 3.44497L15.0911 2.78206ZM12.9698 3.84272C13.2627 3.54982 13.7376 3.54982 14.0305 3.84272L14.6934 4.50563C14.9863 4.79852 14.9863 5.2734 14.6934 5.56629L14.044 6.21573L12.3204 4.49215L12.9698 3.84272ZM11.2597 5.55281L5.6359 11.1766C5.53309 11.2794 5.46238 11.4099 5.43238 11.5522L5.01758 13.5185L6.98394 13.1037C7.1262 13.0737 7.25666 13.003 7.35947 12.9002L12.9833 7.27639L11.2597 5.55281Z"
                fill="currentColor"
              />
            </svg>
            Edit
          </button>
        </div>
      </div>

      {/* Modal */}
      {isOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50">
          <div className="relative w-full max-w-2xl p-6 bg-gray-900 rounded-2xl text-white">
            <div className="mb-6">
              <h4 className="text-2xl font-semibold mb-2">Edit Address</h4>
              <p className="text-sm text-gray-400">
                Update your details to keep your profile up-to-date.
              </p>
            </div>
            
            <div className="grid grid-cols-1 gap-6 md:grid-cols-2">
              <div>
                <label className="block mb-2 text-sm font-medium">Country</label>
                <input
                  type="text"
                  name="country"
                  value={formData.country}
                  onChange={handleInputChange}
                  className="w-full px-4 py-2 bg-gray-800 border border-gray-700 rounded-lg focus:ring-2 focus:ring-blue-500"
                />
              </div>

              <div>
                <label className="block mb-2 text-sm font-medium">City/State</label>
                <input
                  type="text"
                  name="cityState"
                  value={formData.cityState}
                  onChange={handleInputChange}
                  className="w-full px-4 py-2 bg-gray-800 border border-gray-700 rounded-lg focus:ring-2 focus:ring-blue-500"
                />
              </div>

              <div>
                <label className="block mb-2 text-sm font-medium">Postal Code</label>
                <input
                  type="text"
                  name="postalCode"
                  value={formData.postalCode}
                  onChange={handleInputChange}
                  className="w-full px-4 py-2 bg-gray-800 border border-gray-700 rounded-lg focus:ring-2 focus:ring-blue-500"
                />
              </div>

              <div>
                <label className="block mb-2 text-sm font-medium">TAX ID</label>
                <input
                  type="text"
                  name="taxId"
                  value={formData.taxId}
                  onChange={handleInputChange}
                  className="w-full px-4 py-2 bg-gray-800 border border-gray-700 rounded-lg focus:ring-2 focus:ring-blue-500"
                />
              </div>
            </div>

            <div className="flex justify-end gap-3 mt-8">
              <button
                onClick={closeModal}
                className="px-4 py-2 border border-gray-600 rounded-lg hover:bg-gray-800"
              >
                Close
              </button>
              <button
                onClick={handleSave}
                className="px-4 py-2 bg-blue-600 rounded-lg hover:bg-blue-700"
              >
                Save Changes
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}