#!/bin/bash
sqlite data/trend.s3db 'DELETE FROM [Commits] WHERE [Error] IS NOT NULL'
sqlite data/trend.s3db 'DELETE FROM [Results] WHERE [Error] IS NOT NULL'
