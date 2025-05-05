import User from '../models/User.js';

/* export const getApiKeys = async (req, res) => {
  try {
    const keys = await User.getApiKeys(req.user.id);
    
    res.json({
      price: keys.wildberries_price,
      content: keys.wildberries_content
    });
  } catch (error) {
    console.error('Failed to get API keys:', error);
    res.status(500).json({ message: 'Ошибка получения ключей' });
  }
};

export const updateApiKey = async (req, res) => {
  const { keyType, apiKey } = req.body;
  
  try {
    await User.updateApiKey(
      req.user.id, 
      `wildberries_${keyType}`, 
      apiKey
    );
    res.json({ success: true });
  } catch (error) {
    console.error('Failed to update API key:', error);
    res.status(500).json({ message: 'Ошибка обновления ключа' });
  }
}; */