import React, { useState } from 'react';
import { Paper, Box, Typography, TextField, Button, Alert } from '@mui/material';
import CatchingPokemonIcon from '@mui/icons-material/CatchingPokemon';
import { API_BASE_URL } from '../config';

export default function AuthPage({ onLoginSuccess }) {
    const [isRegister, setIsRegister] = useState(false);
    const [username, setUsername] = useState('');
    const [password, setPassword] = useState('');
    const [error, setError] = useState('');
    const [message, setMessage] = useState('');

    const handleSubmit = async (e) => {
        e.preventDefault();
        setError('');
        setMessage('');

        const endpoint = isRegister ? 'register' : 'login';
        try {
            const res = await fetch(`${API_BASE_URL}/api/${endpoint}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ username, password })
            });
            const data = await res.json();

            if (!res.ok) {
                throw new Error(data.error || 'Something went wrong');
            }

            if (isRegister) {
                setMessage('Registration successful! Please login.');
                setIsRegister(false);
                setPassword('');
            } else {
                // Pass auth details back up to App.jsx state
                onLoginSuccess(data.token, data.username);
            }
        } catch (err) {
            setError(err.message);
        }
    };

    return (
      
    <Box display="flex" justifyContent="center" alignItems="center">
            <Paper elevation={4} sx={{ p: 4, width: 380, borderRadius: 4, textAlign: 'center' }}>
                <CatchingPokemonIcon sx={{ fontSize: 50, color: '#ef5350', mb: 1 }} />
                <Typography variant="h5" sx={{ fontWeight: 'bold', mb: 3 }}>
                    {isRegister ? 'Create PokéManager Account' : 'Sign In to PokéManager'}
                </Typography>

                {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
                {message && <Alert severity="success" sx={{ mb: 2 }}>{message}</Alert>}

                <Box component="form" onSubmit={handleSubmit} display="flex" flexDirection="column" gap={2.5}>
                    <TextField 
                        label="Username" 
                        variant="outlined" 
                        fullWidth 
                        required
                        value={username}
                        onChange={(e) => setUsername(e.target.value)}
                    />
                    <TextField 
                        label="Password" 
                        type="password" 
                        variant="outlined" 
                        fullWidth 
                        required
                        value={password}
                        onChange={(e) => setPassword(e.target.value)}
                    />
                    <Button type="submit" variant="contained" color="error" size="large" sx={{ fontWeight: 'bold', mt: 1 }}>
                        {isRegister ? 'Register' : 'Login'}
                    </Button>
                </Box>

                <Button 
                    onClick={() => { setIsRegister(!isRegister); setError(''); setMessage(''); }} 
                    sx={{ mt: 2, textTransform: 'none', color: 'text.secondary' }}
                >
                    {isRegister ? 'Already have an account? Login' : "Don't have an account? Register"}
                </Button>
            </Paper>
        </Box>
    );
}
