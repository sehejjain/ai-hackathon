#!/usr/bin/env node

/**
 * Google Maps MCP Server
 * Provides Google Places API integration for finding nearby restaurants
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

class GoogleMapsMCPServer {
  private server: Server;
  private apiKey: string;

  constructor() {
    this.apiKey = process.env.GPLACES_API_KEY || process.env.GOOGLE_MAPS_API_KEY || '';
    
    if (!this.apiKey) {
      console.error('❌ Error: GPLACES_API_KEY or GOOGLE_MAPS_API_KEY environment variable is required');
      process.exit(1);
    }

    this.server = new Server(
      {
        name: 'google-maps-mcp-server',
        version: '0.1.0',
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    this.setupToolHandlers();
    this.setupErrorHandling();
  }

  private setupErrorHandling(): void {
    this.server.onerror = (error) => console.error('[MCP Error]', error);
    process.on('SIGINT', async () => {
      await this.server.close();
      process.exit(0);
    });
  }

  private setupToolHandlers(): void {
    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: [
        {
          name: 'search_nearby',
          description: 'Search for nearby places using Google Places API',
          inputSchema: {
            type: 'object',
            properties: {
              location: {
                type: 'string',
                description: 'Location as latitude,longitude (e.g., "37.7749,-122.4194")',
              },
              radius: {
                type: 'number',
                description: 'Search radius in meters (max 50000)',
                default: 1500,
              },
              type: {
                type: 'string',
                description: 'Place type to search for (e.g., restaurant, cafe, bar)',
                default: 'restaurant',
              },
              maxprice: {
                type: 'number',
                description: 'Maximum price level (0=free, 1=inexpensive, 2=moderate, 3=expensive, 4=very expensive)',
                default: 2,
              },
              keyword: {
                type: 'string',
                description: 'Additional keyword to filter results',
              },
            },
            required: ['location'],
          },
        },
        {
          name: 'get_place_details',
          description: 'Get detailed information about a specific place',
          inputSchema: {
            type: 'object',
            properties: {
              place_id: {
                type: 'string',
                description: 'Google Places place_id',
              },
            },
            required: ['place_id'],
          },
        },
      ],
    }));

    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      switch (request.params.name) {
        case 'search_nearby':
          return await this.handleSearchNearby(request.params.arguments);
        case 'get_place_details':
          return await this.handleGetPlaceDetails(request.params.arguments);
        default:
          throw new Error(`Unknown tool: ${request.params.name}`);
      }
    });
  }

  private async handleSearchNearby(args: any) {
    try {
      const { location, radius = 1500, type = 'restaurant', maxprice = 2, keyword } = args;

      if (!location) {
        throw new Error('Location is required');
      }

      // Build the Google Places API Nearby Search URL
      const baseUrl = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json';
      const params = new URLSearchParams({
        location: location,
        radius: radius.toString(),
        type: type,
        key: this.apiKey,
      });

      if (maxprice !== undefined) {
        params.append('maxprice', maxprice.toString());
      }

      if (keyword) {
        params.append('keyword', keyword);
      }

      const url = `${baseUrl}?${params.toString()}`;
      
      console.log(`🔍 Searching for ${type} near ${location} with max price ${maxprice}`);
      
      const response = await fetch(url);
      const data = await response.json();

      if (data.status !== 'OK' && data.status !== 'ZERO_RESULTS') {
        throw new Error(`Google Places API error: ${data.status} - ${data.error_message || 'Unknown error'}`);
      }

      // Format the results for the agent
      const results = data.results?.slice(0, 10).map((place: any) => ({
        place_id: place.place_id,
        name: place.name,
        address: place.vicinity || place.formatted_address,
        location: place.geometry?.location,
        price_level: place.price_level ?? 'N/A',
        rating: place.rating ?? 'N/A',
        user_ratings_total: place.user_ratings_total ?? 0,
        types: place.types,
        opening_hours: place.opening_hours?.open_now,
        photos: place.photos?.slice(0, 1).map((photo: any) => ({
          reference: photo.photo_reference,
          width: photo.width,
          height: photo.height,
        })),
      })) || [];

      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify({
              status: data.status,
              results_count: results.length,
              search_params: {
                location,
                radius,
                type,
                maxprice,
                keyword,
              },
              places: results,
            }, null, 2),
          },
        ],
      };
    } catch (error) {
      console.error('Error in search_nearby:', error);
      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify({
              error: error instanceof Error ? error.message : 'Unknown error occurred',
              status: 'ERROR',
            }, null, 2),
          },
        ],
        isError: true,
      };
    }
  }

  private async handleGetPlaceDetails(args: any) {
    try {
      const { place_id } = args;

      if (!place_id) {
        throw new Error('place_id is required');
      }

      const url = `https://maps.googleapis.com/maps/api/place/details/json?place_id=${place_id}&key=${this.apiKey}`;
      
      console.log(`📍 Getting details for place: ${place_id}`);
      
      const response = await fetch(url);
      const data = await response.json();

      if (data.status !== 'OK') {
        throw new Error(`Google Places API error: ${data.status} - ${data.error_message || 'Unknown error'}`);
      }

      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify(data.result, null, 2),
          },
        ],
      };
    } catch (error) {
      console.error('Error in get_place_details:', error);
      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify({
              error: error instanceof Error ? error.message : 'Unknown error occurred',
              status: 'ERROR',
            }, null, 2),
          },
        ],
        isError: true,
      };
    }
  }

  async run(): Promise<void> {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('🗺️ Google Maps MCP Server started successfully');
    console.error('📍 Available tools: search_nearby, get_place_details');
    console.error(`🔑 API Key configured: ${this.apiKey ? '✅' : '❌'}`);
  }
}

const server = new GoogleMapsMCPServer();
server.run().catch(console.error);