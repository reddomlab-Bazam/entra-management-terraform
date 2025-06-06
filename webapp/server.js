const express = require('express');
const app = express();
const port = process.env.PORT || 8080;

app.use(express.json());

app.get('/', (req, res) => {
    res.send(`
    <h1>🎯 Entra Management Console</h1>
    <div style="background: #d4edda; padding: 15px; border-radius: 5px; margin: 20px 0;">
        <h3>✅ Infrastructure Status</h3>
        <ul>
            <li>✅ Azure infrastructure deployed</li>
            <li>✅ Web app running on Node.js ${process.version}</li>
            <li>✅ IP restrictions active</li>
            <li>✅ Ready for configuration</li>
        </ul>
    </div>
    <div style="background: #fff3cd; padding: 15px; border-radius: 5px; margin: 20px 0;">
        <h3>⏳ Next Steps</h3>
        <ol>
            <li>Update email addresses in automation variables</li>
            <li>Install PowerShell modules</li>
            <li>Create Azure AD application</li>
            <li>Configure authentication</li>
        </ol>
    </div>
    `);
});

app.get('/health', (req, res) => {
    res.json({ 
        status: 'healthy',
        timestamp: new Date().toISOString(),
        nodeVersion: process.version,
        port: port
    });
});

app.listen(port, () => {
    console.log(`🎯 Entra Management Console running on port ${port}`);
});