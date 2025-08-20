// Test script for the notification API
// Run this with: node test-notification.js

const testNotification = async () => {
  try {
    // Replace with your actual Vercel deployment URL
    const API_URL = 'http://localhost:3000/api/sendNotification'; // For local testing
    // const API_URL = 'https://your-app.vercel.app/api/sendNotification'; // For production
    
    const testData = {
      title: "Test Notification",
      message: "This is a test push notification",
      tokens: ["your-fcm-token-here"] // Replace with actual FCM tokens
    };

    console.log('Sending test notification...');
    console.log('Data:', JSON.stringify(testData, null, 2));
    
    const response = await fetch(API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(testData)
    });

    console.log('Response status:', response.status);
    const result = await response.text();
    console.log('Response body:', result);
    
    if (response.ok) {
      console.log('✅ Notification sent successfully!');
    } else {
      console.log('❌ Error sending notification');
    }
  } catch (error) {
    console.error('❌ Test failed:', error.message);
  }
};

testNotification();
